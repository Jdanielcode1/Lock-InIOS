//
//  DailyRecapService.swift
//  LockIn
//
//  Created by Claude on 31/12/25.
//

import AVFoundation
import UIKit
import CoreImage

@MainActor
class DailyRecapService: ObservableObject {
    static let shared = DailyRecapService()

    @Published var isCompiling = false
    @Published var compilationProgress: Double = 0
    @Published var compiledVideoURL: URL?
    @Published var errorMessage: String?

    // Configuration
    private let clipDuration: TimeInterval = 12.0  // Target ~12 seconds per clip
    private let titleDisplayDuration: TimeInterval = 2.0  // Show title for 2 seconds
    private let checkmarkAnimationDelay: TimeInterval = 0.5  // Delay before checkmark appears
    private let outputFPS: Int32 = 30

    private init() {}

    // MARK: - Public API

    /// Filter today's completed todos that have videos
    func getTodaysTodosWithVideos(from todos: [TodoItem]) -> [TodoItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return todos.filter { todo in
            let todoDate = calendar.startOfDay(for: todo.createdDate)
            return todoDate == today && todo.isCompleted && todo.hasVideo
        }.sorted { $0.createdDate < $1.createdDate }  // Chronological order
    }

    /// Main compilation function
    func compileDailyRecap(todos: [TodoItem]) async throws -> URL {
        guard !todos.isEmpty else {
            throw DailyRecapError.noVideosToCompile
        }

        isCompiling = true
        compilationProgress = 0
        errorMessage = nil

        defer {
            isCompiling = false
        }

        // Collect video URLs
        let videoData: [(todo: TodoItem, url: URL)] = todos.compactMap { todo in
            guard let url = todo.videoURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return (todo, url)
        }

        guard !videoData.isEmpty else {
            throw DailyRecapError.noValidVideos
        }

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyRecap_\(UUID().uuidString)")
            .appendingPathExtension("mov")

        // Compile videos
        try await compileVideosWithOverlays(
            videoData: videoData,
            outputURL: outputURL
        )

        compiledVideoURL = outputURL
        compilationProgress = 1.0

        return outputURL
    }

    /// Reset state for new compilation
    func reset() {
        isCompiling = false
        compilationProgress = 0
        compiledVideoURL = nil
        errorMessage = nil
    }

    // MARK: - Private Compilation Logic

    private func compileVideosWithOverlays(
        videoData: [(todo: TodoItem, url: URL)],
        outputURL: URL
    ) async throws {
        let composition = AVMutableComposition()

        // Create ONE video track and ONE audio track for all clips
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw DailyRecapError.failedToCreateTracks
        }

        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        let totalClips = videoData.count
        var renderSize: CGSize = CGSize(width: 1080, height: 1920)

        // Process each video clip - insert into the SAME track sequentially
        for (index, data) in videoData.enumerated() {
            print("📹 Processing clip \(index + 1)/\(totalClips): \(data.todo.title)")

            let asset = AVURLAsset(url: data.url)
            let duration = try await asset.load(.duration)
            print("   Duration: \(CMTimeGetSeconds(duration))s")

            // Calculate trim duration (12 seconds, or full video if shorter)
            let trimDuration = min(CMTimeGetSeconds(duration), clipDuration)
            let clipTimeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: trimDuration, preferredTimescale: 600)
            )

            // Get video track
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else {
                print("   ⚠️ No video track found, skipping")
                continue
            }

            // Insert video into composition at current time position
            do {
                try compositionVideoTrack.insertTimeRange(
                    clipTimeRange,
                    of: sourceVideoTrack,
                    at: currentTime
                )
                print("   ✅ Inserted video at \(CMTimeGetSeconds(currentTime))s")
            } catch {
                print("   ❌ Failed to insert video: \(error)")
                continue
            }

            // Get transform and size from first clip
            if index == 0 {
                let transform = try await sourceVideoTrack.load(.preferredTransform)
                compositionVideoTrack.preferredTransform = transform

                let naturalSize = try await sourceVideoTrack.load(.naturalSize)
                let isPortrait = transform.a == 0 && abs(transform.b) == 1
                renderSize = isPortrait ?
                    CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize
                print("   Render size: \(renderSize)")
            }

            // Insert audio track (if exists)
            if let compositionAudioTrack = compositionAudioTrack {
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                if let sourceAudioTrack = audioTracks.first {
                    try? compositionAudioTrack.insertTimeRange(
                        clipTimeRange,
                        of: sourceAudioTrack,
                        at: currentTime
                    )
                }
            }

            // Move to next position
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: trimDuration, preferredTimescale: 600))

            // Update progress
            await MainActor.run {
                compilationProgress = Double(index + 1) / Double(totalClips) * 0.7
            }
        }

        print("📊 Total composition duration: \(CMTimeGetSeconds(composition.duration))s")
        print("📊 Expected duration: \(CMTimeGetSeconds(currentTime))s")

        // Export
        try await exportVideoReencoded(
            composition: composition,
            renderSize: renderSize,
            outputURL: outputURL
        )
    }

    /// Export with re-encoding to ensure compatibility
    private func exportVideoReencoded(
        composition: AVMutableComposition,
        renderSize: CGSize,
        outputURL: URL
    ) async throws {
        // Use Passthrough preset - works best for concatenating similar video sources
        // This preserves the original encoding and is most reliable
        let preset = AVAssetExportPresetPassthrough
        let selectedFileType: AVFileType = .mov

        print("🎬 Using preset: \(preset), fileType: \(selectedFileType)")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset
        ) else {
            print("❌ Failed to create export session")
            throw DailyRecapError.exportFailed
        }

        // Update output URL extension based on file type
        var finalOutputURL = outputURL
        if selectedFileType == .mov && outputURL.pathExtension != "mov" {
            finalOutputURL = outputURL.deletingPathExtension().appendingPathExtension("mov")
        } else if selectedFileType == .mp4 && outputURL.pathExtension != "mp4" {
            finalOutputURL = outputURL.deletingPathExtension().appendingPathExtension("mp4")
        }

        exportSession.outputURL = finalOutputURL
        exportSession.outputFileType = selectedFileType
        exportSession.shouldOptimizeForNetworkUse = true

        print("🚀 Starting export to: \(finalOutputURL.lastPathComponent)")
        await exportSession.export()
        print("📤 Export status: \(exportSession.status.rawValue)")

        switch exportSession.status {
        case .completed:
            print("✅ Export completed successfully!")
            await MainActor.run {
                compilationProgress = 1.0
                compiledVideoURL = finalOutputURL
            }
        case .failed:
            print("❌ Export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            if let error = exportSession.error as NSError? {
                print("   Error domain: \(error.domain)")
                print("   Error code: \(error.code)")
                print("   User info: \(error.userInfo)")
            }
            throw exportSession.error ?? DailyRecapError.exportFailed
        case .cancelled:
            throw DailyRecapError.exportCancelled
        default:
            throw DailyRecapError.exportFailed
        }
    }

    // MARK: - Overlay Layers

    /// Creates the overlay layer with title text and checkmark animation
    private func createOverlayLayer(
        title: String,
        startTime: CMTime,
        clipDuration: CMTime,
        renderSize: CGSize
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: renderSize)
        containerLayer.opacity = 0  // Start hidden

        // Calculate font size based on render size
        let fontSize: CGFloat = min(renderSize.width, renderSize.height) * 0.05
        let padding: CGFloat = 20
        let bannerHeight: CGFloat = fontSize * 2.5

        // Background blur/dim effect for readability (lower third)
        let backgroundLayer = CALayer()
        backgroundLayer.frame = CGRect(
            x: 0,
            y: renderSize.height - bannerHeight - 60,  // Lower third
            width: renderSize.width,
            height: bannerHeight
        )
        backgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.6).cgColor
        containerLayer.addSublayer(backgroundLayer)

        // Title text layer
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.font = CTFontCreateWithName("SF Pro Display Bold" as CFString, fontSize, nil)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.shadowRadius = 4
        textLayer.shadowOpacity = 0.8
        textLayer.alignmentMode = .left
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.frame = CGRect(
            x: padding,
            y: renderSize.height - bannerHeight - 60 + (bannerHeight - fontSize) / 2,
            width: renderSize.width - 100,  // Leave room for checkmark
            height: fontSize * 1.5
        )
        textLayer.truncationMode = .end
        containerLayer.addSublayer(textLayer)

        // Checkmark layer
        let checkmarkLayer = createCheckmarkLayer(size: CGSize(width: fontSize * 1.5, height: fontSize * 1.5))
        checkmarkLayer.position = CGPoint(
            x: renderSize.width - padding - fontSize,
            y: renderSize.height - bannerHeight - 60 + bannerHeight / 2
        )
        checkmarkLayer.opacity = 0  // Start hidden for animation
        containerLayer.addSublayer(checkmarkLayer)

        // ANIMATIONS
        let startSeconds = CMTimeGetSeconds(startTime)

        // Container fade in
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.3
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        containerLayer.add(fadeIn, forKey: "fadeIn")

        // Container fade out (after title display)
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = 0.3
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds + titleDisplayDuration
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        containerLayer.add(fadeOut, forKey: "fadeOut")

        // Checkmark scale animation (pop in)
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [0, 1.3, 1.0]
        scaleAnimation.keyTimes = [0, 0.6, 1.0]
        scaleAnimation.duration = 0.4
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds + checkmarkAnimationDelay
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        checkmarkLayer.add(scaleAnimation, forKey: "scale")

        // Checkmark opacity animation
        let checkOpacity = CABasicAnimation(keyPath: "opacity")
        checkOpacity.fromValue = 0
        checkOpacity.toValue = 1
        checkOpacity.duration = 0.2
        checkOpacity.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds + checkmarkAnimationDelay
        checkOpacity.fillMode = .forwards
        checkOpacity.isRemovedOnCompletion = false
        checkmarkLayer.add(checkOpacity, forKey: "opacity")

        return containerLayer
    }

    /// Creates a checkmark shape layer with circle background
    private func createCheckmarkLayer(size: CGSize) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2), size: size)

        // Circle background
        let circleLayer = CAShapeLayer()
        let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.green.cgColor
        circleLayer.frame = CGRect(origin: .zero, size: size)
        containerLayer.addSublayer(circleLayer)

        // Checkmark
        let checkmarkLayer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.5))
        path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.68))
        path.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.32))

        checkmarkLayer.path = path.cgPath
        checkmarkLayer.strokeColor = UIColor.white.cgColor
        checkmarkLayer.fillColor = UIColor.clear.cgColor
        checkmarkLayer.lineWidth = size.width * 0.12
        checkmarkLayer.lineCap = .round
        checkmarkLayer.lineJoin = .round
        checkmarkLayer.frame = CGRect(origin: .zero, size: size)
        containerLayer.addSublayer(checkmarkLayer)

        return containerLayer
    }
}

// MARK: - Error Types

enum DailyRecapError: Error, LocalizedError {
    case noVideosToCompile
    case noValidVideos
    case invalidVideoTrack
    case failedToCreateTracks
    case exportFailed
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .noVideosToCompile:
            return "No completed todos with videos today"
        case .noValidVideos:
            return "No valid video files found"
        case .invalidVideoTrack:
            return "Failed to load video track"
        case .failedToCreateTracks:
            return "Failed to create composition tracks"
        case .exportFailed:
            return "Failed to export video"
        case .exportCancelled:
            return "Export was cancelled"
        }
    }
}
