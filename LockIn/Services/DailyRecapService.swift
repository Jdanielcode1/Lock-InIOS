//
//  DailyRecapService.swift
//  LockIn
//
//  Created by Claude on 31/12/25.
//

import AVFoundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class DailyRecapService: ObservableObject {
    static let shared = DailyRecapService()

    @Published var isCompiling = false
    @Published var compilationProgress: Double = 0
    @Published var compiledVideoURL: URL?
    @Published var errorMessage: String?
    @Published var clipTimings: [(title: String, startTime: Double, duration: Double)] = []

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

        // Sort todos chronologically (oldest first)
        let sortedTodos = todos.sorted { $0.createdDate < $1.createdDate }

        // Collect video URLs
        let videoData: [(todo: TodoItem, url: URL)] = sortedTodos.compactMap { todo in
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
        clipTimings = []
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

        // Track clip data for overlay timing
        var clipTimingData: [(todo: TodoItem, startTime: CMTime, duration: Double)] = []

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

                // Track timing for overlay
                clipTimingData.append((todo: data.todo, startTime: currentTime, duration: trimDuration))
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

        // Store clip timing data for overlays (including speed segments for accurate stopwatch)
        let overlayData = clipTimingData.map { (
            title: $0.todo.title,
            startTime: CMTimeGetSeconds($0.startTime),
            duration: $0.duration,
            speedSegments: $0.todo.speedSegments
        ) }
        await MainActor.run {
            self.clipTimings = overlayData.map { ($0.title, $0.startTime, $0.duration) }
        }

        // Step 1: Export concatenated video (Passthrough - fast & reliable)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyRecap_temp_\(UUID().uuidString)")
            .appendingPathExtension("mov")

        try await exportVideoSimple(composition: composition, outputURL: tempURL)

        await MainActor.run {
            compilationProgress = 0.8
        }

        // Step 2: Re-encode with burned-in overlays
        try await burnInOverlays(
            sourceURL: tempURL,
            overlayData: overlayData,
            outputURL: outputURL
        )

        // Cleanup temp file
        try? FileManager.default.removeItem(at: tempURL)
    }

    /// Burn overlays into a video file using CIFilter
    private func burnInOverlays(
        sourceURL: URL,
        overlayData: [(title: String, startTime: Double, duration: Double, speedSegments: [SpeedSegment]?)],
        outputURL: URL
    ) async throws {
        print("🔥 Burning in overlays to video...")

        let asset = AVURLAsset(url: sourceURL)

        // Get video properties
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw DailyRecapError.invalidVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let isPortrait = transform.a == 0 && abs(transform.b) == 1
        let renderSize = isPortrait ?
            CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize

        print("   Render size: \(renderSize)")

        // Pre-render badge images (must be done before closure)
        let overlayDisplayDuration = 3.0
        var overlayBadges: [(badge: CIImage, title: String, startTime: Double, endTime: Double)] = []

        for data in overlayData {
            let endTime = data.startTime + min(data.duration, overlayDisplayDuration)
            // Pre-render badge at full opacity - we'll apply opacity in the filter
            if let badge = createPremiumBadge(title: data.title, opacity: 1.0, videoSize: renderSize) {
                overlayBadges.append((badge: badge, title: data.title, startTime: data.startTime, endTime: endTime))
                print("   Badge: \(data.title) @ \(data.startTime)s-\(endTime)s, size: \(badge.extent.size)")
            } else {
                print("   ❌ Failed to create badge for: \(data.title)")
            }
        }

        // Calculate max real time we might need to display (per-clip and cumulative)
        var maxRealSecondsPerClip = Int(clipDuration) + 1  // Default fallback
        var totalCumulativeRealTime: Double = 0

        // First pass: calculate each clip's real duration and cumulative total
        var clipRealDurations: [Double] = []
        for data in overlayData {
            var clipRealDuration = data.duration  // Default: video duration = real duration (1x speed)
            if let segments = data.speedSegments, let lastSegment = segments.last {
                clipRealDuration = lastSegment.endRealTime
                maxRealSecondsPerClip = max(maxRealSecondsPerClip, Int(clipRealDuration) + 1)
            }
            clipRealDurations.append(clipRealDuration)
            totalCumulativeRealTime += clipRealDuration
        }

        // Cap at 60 minutes for per-clip, but allow up to 4 hours for cumulative
        maxRealSecondsPerClip = min(maxRealSecondsPerClip, 3600)
        let maxCumulativeSeconds = min(Int(totalCumulativeRealTime) + 1, 14400) // 4 hours max

        // Pre-render stopwatch images for per-clip timer
        var stopwatchCache: [Int: CIImage] = [:]
        for sec in 0..<maxRealSecondsPerClip {
            if let img = createStopwatchOverlay(seconds: sec, videoSize: renderSize, opacity: 1.0) {
                stopwatchCache[sec] = img
            }
        }
        print("   ⏱️ Pre-rendered \(stopwatchCache.count) per-clip stopwatch images")

        // Pre-render cumulative total timer images (with "TOTAL" label style)
        var cumulativeCache: [Int: CIImage] = [:]
        for sec in 0..<maxCumulativeSeconds {
            if let img = createTotalTimeOverlay(seconds: sec, videoSize: renderSize, opacity: 1.0) {
                cumulativeCache[sec] = img
            }
        }
        print("   ⏱️ Pre-rendered \(cumulativeCache.count) cumulative timer images (total \(Int(totalCumulativeRealTime))s)")

        // Build clip time ranges with cumulative offset and clip duration
        var clipRanges: [(startTime: Double, endTime: Double, speedSegments: [SpeedSegment]?, cumulativeOffset: Double, clipDuration: Double)] = []
        var cumulativeOffset: Double = 0
        for (index, data) in overlayData.enumerated() {
            clipRanges.append((
                startTime: data.startTime,
                endTime: data.startTime + data.duration,
                speedSegments: data.speedSegments,
                cumulativeOffset: cumulativeOffset,
                clipDuration: data.duration  // The trimmed clip duration (max 12s)
            ))
            cumulativeOffset += clipRealDurations[index]
        }

        // Capture the calculateRealTime function for use in the closure
        let calculateRealTimeFunc = self.calculateRealTime

        // Create video composition with CIFilter handler
        var frameCount = 0
        let videoComposition = AVMutableVideoComposition(asset: asset) { request in
            frameCount += 1
            let currentTime = CMTimeGetSeconds(request.compositionTime)
            var outputImage = request.sourceImage

            if frameCount % 30 == 1 {
                print("   🎞️ Processing frame \(frameCount) at \(String(format: "%.2f", currentTime))s")
            }

            // Check if any overlay should be visible
            for badge in overlayBadges {
                if currentTime >= badge.startTime && currentTime <= badge.endTime {
                    if frameCount % 30 == 1 {
                        print("   ✨ Applying badge '\(badge.title)' at \(String(format: "%.2f", currentTime))s")
                    }

                    // Calculate fade opacity
                    let fadeInDuration = 0.3
                    let fadeOutDuration = 0.4
                    var opacity: CGFloat = 1.0

                    let timeIntoOverlay = currentTime - badge.startTime
                    let timeUntilEnd = badge.endTime - currentTime

                    if timeIntoOverlay < fadeInDuration {
                        opacity = CGFloat(timeIntoOverlay / fadeInDuration)
                    } else if timeUntilEnd < fadeOutDuration {
                        opacity = CGFloat(timeUntilEnd / fadeOutDuration)
                    }

                    // Position badge in top-left (CIImage origin is bottom-left)
                    let scale = min(request.renderSize.width, request.renderSize.height) / 1280.0
                    let padding: CGFloat = 20 * scale
                    let yPos = request.renderSize.height - padding - badge.badge.extent.height - (70 * scale)

                    // Apply opacity and position
                    let positioned = badge.badge
                        .transformed(by: CGAffineTransform(translationX: padding, y: yPos))
                        .applyingFilter("CIColorMatrix", parameters: [
                            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
                        ])

                    outputImage = positioned.composited(over: outputImage)
                    break
                }
            }

            // Composite stopwatch overlays (always visible for entire clip)
            // Uses speed segments to show accurate real elapsed time
            for clip in clipRanges {
                if currentTime >= clip.startTime && currentTime < clip.endTime {
                    let videoTimeInClip = currentTime - clip.startTime

                    // Calculate real elapsed time using speed segments
                    // The stopwatch is scaled to show the FULL recording duration within the trimmed clip
                    let realElapsedTime = calculateRealTimeFunc(
                        videoTimeInClip,
                        clip.speedSegments,
                        clip.clipDuration  // Pass the actual trimmed clip duration
                    )

                    let scale = min(request.renderSize.width, request.renderSize.height) / 1280.0
                    let padding: CGFloat = 20 * scale

                    // 1. Per-clip timer (bottom-right)
                    let perClipSeconds = min(Int(realElapsedTime), maxRealSecondsPerClip - 1)
                    if let stopwatchImage = stopwatchCache[perClipSeconds] {
                        let xPos = request.renderSize.width - stopwatchImage.extent.width - padding
                        let yPos = padding

                        let positioned = stopwatchImage
                            .transformed(by: CGAffineTransform(translationX: xPos, y: yPos))

                        outputImage = positioned.composited(over: outputImage)
                    }

                    // 2. Cumulative total timer (bottom-left)
                    let cumulativeTime = clip.cumulativeOffset + realElapsedTime
                    let cumulativeSeconds = min(Int(cumulativeTime), maxCumulativeSeconds - 1)
                    if let cumulativeImage = cumulativeCache[cumulativeSeconds] {
                        let xPos = padding
                        let yPos = padding

                        let positioned = cumulativeImage
                            .transformed(by: CGAffineTransform(translationX: xPos, y: yPos))

                        outputImage = positioned.composited(over: outputImage)
                    }

                    break
                }
            }

            request.finish(with: outputImage, context: nil)
        }

        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw DailyRecapError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        print("🚀 Exporting with overlays...")
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            print("✅ Burned-in overlay export complete!")
            await MainActor.run {
                compilationProgress = 1.0
                compiledVideoURL = outputURL
            }
        case .failed:
            print("❌ Burn-in export failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            if let error = exportSession.error as NSError? {
                print("   Error code: \(error.code)")
            }
            throw exportSession.error ?? DailyRecapError.exportFailed
        case .cancelled:
            throw DailyRecapError.exportCancelled
        default:
            throw DailyRecapError.exportFailed
        }
    }

    /// Simple export without video composition (reliable)
    private func exportVideoSimple(
        composition: AVMutableComposition,
        outputURL: URL
    ) async throws {
        let preset = AVAssetExportPresetPassthrough
        print("🎬 Using simple passthrough export")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset
        ) else {
            print("❌ Failed to create export session")
            throw DailyRecapError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true

        print("🚀 Starting export to: \(outputURL.lastPathComponent)")
        await exportSession.export()
        print("📤 Export status: \(exportSession.status.rawValue)")

        switch exportSession.status {
        case .completed:
            print("✅ Export completed successfully!")
            await MainActor.run {
                compilationProgress = 1.0
                compiledVideoURL = outputURL
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

    /// Export with CIFilter-based text overlays (legacy - unused)
    private func exportVideoWithOverlays(
        composition: AVMutableComposition,
        clipTimingData: [(todo: TodoItem, startTime: CMTime, duration: Double)],
        renderSize: CGSize,
        outputURL: URL
    ) async throws {
        print("🎨 Setting up CIFilter-based text overlays...")

        // Pre-render all text overlay images
        var overlayImages: [(image: CIImage, startTime: Double, endTime: Double)] = []
        for data in clipTimingData {
            let startSeconds = CMTimeGetSeconds(data.startTime)
            let endSeconds = startSeconds + min(data.duration, titleDisplayDuration + 1.0)  // Show for ~3 seconds

            if let textImage = createTextOverlayImage(
                title: data.todo.title,
                renderSize: renderSize
            ) {
                overlayImages.append((image: textImage, startTime: startSeconds, endTime: endSeconds))
                print("   Created overlay for: \(data.todo.title) (\(startSeconds)s - \(endSeconds)s)")
            }
        }

        // Create video composition with CIFilter handler
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let currentTime = CMTimeGetSeconds(request.compositionTime)
            var outputImage = request.sourceImage.clampedToExtent()

            // Check if any overlay should be visible at this time
            for overlay in overlayImages {
                if currentTime >= overlay.startTime && currentTime <= overlay.endTime {
                    // Calculate fade in/out opacity
                    let fadeInDuration = 0.3
                    let fadeOutDuration = 0.4
                    var opacity: CGFloat = 1.0

                    let timeIntoOverlay = currentTime - overlay.startTime
                    let timeUntilEnd = overlay.endTime - currentTime

                    if timeIntoOverlay < fadeInDuration {
                        opacity = CGFloat(timeIntoOverlay / fadeInDuration)
                    } else if timeUntilEnd < fadeOutDuration {
                        opacity = CGFloat(timeUntilEnd / fadeOutDuration)
                    }

                    // Apply opacity to overlay
                    let overlayWithOpacity = overlay.image.applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
                    ])

                    // Composite overlay on top of video
                    if let compositeFilter = CIFilter(name: "CISourceOverCompositing") {
                        compositeFilter.setValue(overlayWithOpacity, forKey: kCIInputImageKey)
                        compositeFilter.setValue(outputImage, forKey: kCIInputBackgroundImageKey)
                        if let result = compositeFilter.outputImage {
                            outputImage = result
                        }
                    }
                    break  // Only show one overlay at a time
                }
            }

            // Crop to render size
            let cropped = outputImage.cropped(to: CGRect(origin: .zero, size: renderSize))
            request.finish(with: cropped, context: nil)
        }

        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Export
        let preset = AVAssetExportPresetHighestQuality
        print("🎬 Using preset: \(preset) with CIFilter overlays")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset
        ) else {
            print("❌ Failed to create export session")
            throw DailyRecapError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        print("🚀 Starting export with CIFilter overlays to: \(outputURL.lastPathComponent)")
        await exportSession.export()
        print("📤 Export status: \(exportSession.status.rawValue)")

        switch exportSession.status {
        case .completed:
            print("✅ Export completed successfully with overlays!")
            await MainActor.run {
                compilationProgress = 1.0
                compiledVideoURL = outputURL
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

    /// Creates a premium rounded badge with checkmark and title
    private func createPremiumBadge(title: String, opacity: CGFloat, videoSize: CGSize) -> CIImage? {
        let scale = min(videoSize.width, videoSize.height) / 1280.0

        // === DESIGN TOKENS (YC Startup Aesthetic) ===
        let badgeHeight: CGFloat = 56 * scale
        let cornerRadius: CGFloat = badgeHeight / 2  // Full pill shape
        let horizontalPadding: CGFloat = 18 * scale
        let checkmarkSize: CGFloat = 32 * scale
        let spacing: CGFloat = 12 * scale
        let fontSize: CGFloat = 20 * scale

        // Calculate text width
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (title as NSString).size(withAttributes: textAttributes)
        let maxTextWidth = videoSize.width * 0.5
        let actualTextWidth = min(textSize.width, maxTextWidth)

        // Total badge width
        let badgeWidth = horizontalPadding + checkmarkSize + spacing + actualTextWidth + horizontalPadding

        // Create image with enough space for shadow
        let shadowPadding: CGFloat = 16 * scale
        let canvasWidth = badgeWidth + shadowPadding * 2
        let canvasHeight = badgeHeight + shadowPadding * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        let image = renderer.image { context in
            let ctx = context.cgContext

            // Badge rect (centered in canvas for shadow room)
            let badgeRect = CGRect(x: shadowPadding, y: shadowPadding, width: badgeWidth, height: badgeHeight)
            let pillPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)

            // === SHADOW ===
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 4 * scale), blur: 12 * scale, color: UIColor.black.withAlphaComponent(0.4 * opacity).cgColor)
            UIColor.black.setFill()
            pillPath.fill()
            ctx.restoreGState()

            // === MAIN BACKGROUND (Dark glass) ===
            UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.92 * opacity).setFill()
            pillPath.fill()

            // === SUBTLE BORDER ===
            UIColor.white.withAlphaComponent(0.1 * opacity).setStroke()
            pillPath.lineWidth = 1
            pillPath.stroke()

            // === GREEN CHECKMARK CIRCLE ===
            let circleX = badgeRect.minX + horizontalPadding
            let circleY = badgeRect.midY - checkmarkSize / 2
            let circleRect = CGRect(x: circleX, y: circleY, width: checkmarkSize, height: checkmarkSize)

            // Circle with gradient feel
            let circlePath = UIBezierPath(ovalIn: circleRect)
            UIColor(red: 0.22, green: 0.8, blue: 0.42, alpha: opacity).setFill()
            circlePath.fill()

            // === CHECKMARK ===
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(opacity).cgColor)
            ctx.setLineWidth(2.5 * scale)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let checkPath = UIBezierPath()
            let cx = circleRect.midX
            let cy = circleRect.midY
            let cs = checkmarkSize * 0.28

            checkPath.move(to: CGPoint(x: cx - cs, y: cy))
            checkPath.addLine(to: CGPoint(x: cx - cs * 0.3, y: cy + cs * 0.7))
            checkPath.addLine(to: CGPoint(x: cx + cs, y: cy - cs * 0.6))
            ctx.addPath(checkPath.cgPath)
            ctx.strokePath()

            // === TITLE TEXT ===
            let textX = circleX + checkmarkSize + spacing
            let textY = badgeRect.midY - fontSize * 0.6

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(opacity),
                .paragraphStyle: paragraphStyle
            ]

            let textRect = CGRect(x: textX, y: textY, width: actualTextWidth, height: fontSize * 1.4)
            (title as NSString).draw(in: textRect, withAttributes: textAttrs)
        }

        return CIImage(image: image)
    }

    /// Creates a stopwatch overlay showing elapsed time (MM:SS format)
    private func createStopwatchOverlay(seconds: Int, videoSize: CGSize, opacity: CGFloat) -> CIImage? {
        let scale = min(videoSize.width, videoSize.height) / 1280.0

        // === DESIGN TOKENS ===
        let badgeHeight: CGFloat = 44 * scale
        let cornerRadius: CGFloat = badgeHeight / 2
        let horizontalPadding: CGFloat = 16 * scale
        let fontSize: CGFloat = 22 * scale

        // Format time as MM:SS
        let minutes = seconds / 60
        let secs = seconds % 60
        let timeText = String(format: "%02d:%02d", minutes, secs)

        // Use monospace font for consistent width
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (timeText as NSString).size(withAttributes: textAttributes)

        // Total badge width
        let badgeWidth = horizontalPadding * 2 + textSize.width

        // Create image with shadow padding
        let shadowPadding: CGFloat = 12 * scale
        let canvasWidth = badgeWidth + shadowPadding * 2
        let canvasHeight = badgeHeight + shadowPadding * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        let image = renderer.image { context in
            let ctx = context.cgContext

            // Badge rect (centered in canvas for shadow room)
            let badgeRect = CGRect(x: shadowPadding, y: shadowPadding, width: badgeWidth, height: badgeHeight)
            let pillPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)

            // === SHADOW ===
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 3 * scale), blur: 8 * scale, color: UIColor.black.withAlphaComponent(0.35 * opacity).cgColor)
            UIColor.black.setFill()
            pillPath.fill()
            ctx.restoreGState()

            // === MAIN BACKGROUND (Dark glass) ===
            UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.85 * opacity).setFill()
            pillPath.fill()

            // === SUBTLE BORDER ===
            UIColor.white.withAlphaComponent(0.1 * opacity).setStroke()
            pillPath.lineWidth = 1
            pillPath.stroke()

            // === TIME TEXT ===
            let textX = badgeRect.minX + horizontalPadding
            let textY = badgeRect.midY - fontSize * 0.55

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(opacity)
            ]

            let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: fontSize * 1.3)
            (timeText as NSString).draw(in: textRect, withAttributes: textAttrs)
        }

        return CIImage(image: image)
    }

    /// Creates a total/cumulative time overlay with "TOTAL" label
    private func createTotalTimeOverlay(seconds: Int, videoSize: CGSize, opacity: CGFloat) -> CIImage? {
        let scale = min(videoSize.width, videoSize.height) / 1280.0

        // === DESIGN TOKENS ===
        let badgeHeight: CGFloat = 44 * scale
        let cornerRadius: CGFloat = badgeHeight / 2
        let horizontalPadding: CGFloat = 14 * scale
        let fontSize: CGFloat = 18 * scale
        let iconSize: CGFloat = 16 * scale

        // Format time as MM:SS or HH:MM:SS for longer durations
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        let timeText: String
        if hours > 0 {
            timeText = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            timeText = String(format: "%02d:%02d", minutes, secs)
        }

        // Use monospace font for consistent width
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (timeText as NSString).size(withAttributes: textAttributes)

        // Total badge width (icon + TOTAL label + time)
        let spacing: CGFloat = 6 * scale
        let badgeWidth = horizontalPadding + iconSize + spacing + textSize.width + horizontalPadding

        // Create image with shadow padding
        let shadowPadding: CGFloat = 12 * scale
        let canvasWidth = badgeWidth + shadowPadding * 2
        let canvasHeight = badgeHeight + shadowPadding * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        let image = renderer.image { context in
            let ctx = context.cgContext

            // Badge rect (centered in canvas for shadow room)
            let badgeRect = CGRect(x: shadowPadding, y: shadowPadding, width: badgeWidth, height: badgeHeight)
            let pillPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)

            // === SHADOW ===
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 3 * scale), blur: 8 * scale, color: UIColor.black.withAlphaComponent(0.35 * opacity).cgColor)
            UIColor.black.setFill()
            pillPath.fill()
            ctx.restoreGState()

            // === MAIN BACKGROUND (Purple tint to differentiate from per-clip timer) ===
            UIColor(red: 0.15, green: 0.1, blue: 0.2, alpha: 0.88 * opacity).setFill()
            pillPath.fill()

            // === SUBTLE BORDER ===
            UIColor.white.withAlphaComponent(0.15 * opacity).setStroke()
            pillPath.lineWidth = 1
            pillPath.stroke()

            // === SIGMA/SUM ICON (Σ) ===
            let iconX = badgeRect.minX + horizontalPadding
            let iconY = badgeRect.midY - iconSize * 0.5

            // Draw sum symbol
            let sumFont = UIFont.systemFont(ofSize: iconSize * 1.1, weight: .bold)
            let sumAttrs: [NSAttributedString.Key: Any] = [
                .font: sumFont,
                .foregroundColor: UIColor(red: 0.6, green: 0.5, blue: 1.0, alpha: opacity)  // Purple accent
            ]
            let sumRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            ("Σ" as NSString).draw(in: sumRect, withAttributes: sumAttrs)

            // === TIME TEXT ===
            let textX = iconX + iconSize + spacing
            let textY = badgeRect.midY - fontSize * 0.55

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(opacity)
            ]

            let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: fontSize * 1.3)
            (timeText as NSString).draw(in: textRect, withAttributes: textAttrs)
        }

        return CIImage(image: image)
    }

    /// Calculate real elapsed time from video position using speed segments
    /// Returns the actual recording time at a given video playback position
    ///
    /// IMPORTANT: This function now scales the real time to fit within the visible clip duration.
    /// Since recap clips are trimmed to 12 seconds, we scale the stopwatch so it shows
    /// the FULL recording duration within those 12 seconds of video.
    private func calculateRealTime(
        videoTimeInClip: Double,
        speedSegments: [SpeedSegment]?,
        clipVideoDuration: Double = 12.0  // The trimmed clip duration (default 12s)
    ) -> Double {
        // If no segments, assume 1x speed (video time = real time)
        guard let segments = speedSegments, !segments.isEmpty else {
            return videoTimeInClip
        }

        // Get the total real recording duration from speed segments
        guard let lastSegment = segments.last else {
            return videoTimeInClip
        }
        let totalRealDuration = lastSegment.endRealTime

        // Get the total video duration (all frames at 30fps)
        let totalFrames = lastSegment.endFrameIndex
        let totalVideoDuration = Double(totalFrames) / 30.0

        // If the full video is shorter than clip duration, no scaling needed
        if totalVideoDuration <= clipVideoDuration {
            // Use the original frame-based calculation
            let currentFrame = Int(videoTimeInClip * 30)

            for segment in segments {
                if currentFrame >= segment.startFrameIndex && currentFrame < segment.endFrameIndex {
                    let framesIntoSegment = currentFrame - segment.startFrameIndex
                    let totalFramesInSegment = segment.endFrameIndex - segment.startFrameIndex
                    let progress = totalFramesInSegment > 0 ?
                        Double(framesIntoSegment) / Double(totalFramesInSegment) : 0.0
                    let segmentRealDuration = segment.endRealTime - segment.startRealTime
                    return segment.startRealTime + (progress * segmentRealDuration)
                }
            }

            if currentFrame >= lastSegment.endFrameIndex {
                return lastSegment.endRealTime
            }
            return videoTimeInClip
        }

        // Scale the stopwatch to show full recording duration within the trimmed clip
        // This makes the stopwatch count from 0 to totalRealDuration over clipVideoDuration seconds
        let progress = min(videoTimeInClip / clipVideoDuration, 1.0)
        return progress * totalRealDuration
    }

    /// Creates a text overlay image using Core Graphics
    private func createTextOverlayImage(title: String, renderSize: CGSize) -> CIImage? {
        let fontSize: CGFloat = min(renderSize.width, renderSize.height) * 0.04
        let padding: CGFloat = 30
        let badgeHeight: CGFloat = fontSize * 2.2
        let checkmarkSize: CGFloat = fontSize * 1.4

        // Calculate badge dimensions
        let maxTextWidth = renderSize.width * 0.6
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let textSize = (title as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: badgeHeight),
            options: .usesLineFragmentOrigin,
            attributes: textAttributes,
            context: nil
        ).size

        let badgeWidth = checkmarkSize + textSize.width + padding * 2

        // Create the overlay image
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { context in
            let ctx = context.cgContext

            // Position in top-left corner
            let badgeX: CGFloat = padding
            let badgeY: CGFloat = padding + 60  // Safe area offset

            // Draw pill background
            let pillRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
            let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: badgeHeight / 2)
            UIColor.black.withAlphaComponent(0.75).setFill()
            pillPath.fill()

            // Draw checkmark circle
            let checkmarkX = badgeX + padding / 2
            let checkmarkY = badgeY + (badgeHeight - checkmarkSize) / 2
            let circleRect = CGRect(x: checkmarkX, y: checkmarkY, width: checkmarkSize, height: checkmarkSize)
            UIColor.green.setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            // Draw checkmark
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(checkmarkSize * 0.12)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let checkPath = UIBezierPath()
            checkPath.move(to: CGPoint(
                x: checkmarkX + checkmarkSize * 0.25,
                y: checkmarkY + checkmarkSize * 0.5
            ))
            checkPath.addLine(to: CGPoint(
                x: checkmarkX + checkmarkSize * 0.42,
                y: checkmarkY + checkmarkSize * 0.68
            ))
            checkPath.addLine(to: CGPoint(
                x: checkmarkX + checkmarkSize * 0.75,
                y: checkmarkY + checkmarkSize * 0.32
            ))
            checkPath.stroke()

            // Draw text
            let textX = checkmarkX + checkmarkSize + 8
            let textY = badgeY + (badgeHeight - fontSize * 1.2) / 2
            let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: fontSize * 1.4)
            (title as NSString).draw(in: textRect, withAttributes: textAttributes)
        }

        return CIImage(image: image)
    }

    // MARK: - Overlay Layers

    /// Creates the overlay layer with title text and checkmark animation
    /// Positioned in top-left corner as a compact pill badge
    private func createOverlayLayer(
        title: String,
        startTime: CMTime,
        clipDuration: CMTime,
        renderSize: CGSize
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: renderSize)
        containerLayer.opacity = 0  // Start hidden

        // Calculate sizes based on render dimensions
        let fontSize: CGFloat = min(renderSize.width, renderSize.height) * 0.04
        let padding: CGFloat = 30
        let badgeHeight: CGFloat = fontSize * 2.2
        let checkmarkSize: CGFloat = fontSize * 1.4
        let cornerRadius: CGFloat = badgeHeight / 2

        // Calculate badge width based on text (max 70% of screen width)
        let maxTextWidth = renderSize.width * 0.6
        let textWidth = min(CGFloat(title.count) * fontSize * 0.6, maxTextWidth)
        let badgeWidth = checkmarkSize + textWidth + padding * 1.5

        // Position in top-left corner (accounting for flipped geometry)
        let badgeX: CGFloat = padding
        let badgeY: CGFloat = padding + 60  // Safe area offset

        // Background pill shape
        let backgroundLayer = CAShapeLayer()
        let pillPath = UIBezierPath(
            roundedRect: CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight),
            cornerRadius: cornerRadius
        )
        backgroundLayer.path = pillPath.cgPath
        backgroundLayer.fillColor = UIColor.black.withAlphaComponent(0.75).cgColor
        containerLayer.addSublayer(backgroundLayer)

        // Checkmark layer (left side of badge)
        let checkmarkLayer = createCheckmarkLayer(size: CGSize(width: checkmarkSize, height: checkmarkSize))
        checkmarkLayer.position = CGPoint(
            x: badgeX + padding / 2 + checkmarkSize / 2,
            y: badgeY + badgeHeight / 2
        )
        checkmarkLayer.opacity = 0  // Start hidden for animation
        containerLayer.addSublayer(checkmarkLayer)

        // Title text layer (right of checkmark)
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.font = CTFontCreateWithName("SF Pro Display Semibold" as CFString, fontSize, nil)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = 3.0  // High resolution for crisp text
        textLayer.truncationMode = .end
        textLayer.frame = CGRect(
            x: badgeX + padding / 2 + checkmarkSize + 8,
            y: badgeY + (badgeHeight - fontSize * 1.2) / 2,
            width: textWidth,
            height: fontSize * 1.4
        )
        containerLayer.addSublayer(textLayer)

        // ANIMATIONS
        let startSeconds = CMTimeGetSeconds(startTime)

        // Slide in from left + fade in
        let slideIn = CABasicAnimation(keyPath: "transform.translation.x")
        slideIn.fromValue = -badgeWidth - padding
        slideIn.toValue = 0
        slideIn.duration = 0.4
        slideIn.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds
        slideIn.fillMode = .forwards
        slideIn.isRemovedOnCompletion = false
        slideIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        containerLayer.add(slideIn, forKey: "slideIn")

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.3
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        containerLayer.add(fadeIn, forKey: "fadeIn")

        // Fade out after display duration
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.duration = 0.4
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds + titleDisplayDuration + 0.5
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        containerLayer.add(fadeOut, forKey: "fadeOut")

        // Checkmark pop-in animation (delayed)
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [0, 1.3, 1.0]
        scaleAnimation.keyTimes = [0, 0.6, 1.0]
        scaleAnimation.duration = 0.35
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + startSeconds + checkmarkAnimationDelay
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        checkmarkLayer.add(scaleAnimation, forKey: "scale")

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
