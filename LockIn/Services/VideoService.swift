//
//  VideoService.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import AVFoundation
import UIKit

class VideoService {
    static let shared = VideoService()

    private init() {}

    // MARK: - Video Duration

    /// Get video duration in minutes
    /// - Parameters:
    ///   - url: URL of the video file
    /// - Returns: Duration in minutes
    func getVideoDuration(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        let minutes = seconds / 60.0

        print("⏱️ Video duration: \(minutes) min")
        return minutes
    }

    // MARK: - Video Compression

    func compressVideo(url: URL) async throws -> URL {
        print("🎬 Starting compression for: \(url)")

        // Verify input file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Input file does not exist at: \(url.path)")
            throw VideoServiceError.invalidVideoURL
        }

        // Check if input file exists and has data
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            print("📦 Input file size: \(fileSize) bytes")

            if fileSize == 0 {
                print("❌ Input file is empty!")
                throw VideoServiceError.invalidVideoURL
            }
        } else {
            print("❌ Cannot read input file attributes")
            throw VideoServiceError.invalidVideoURL
        }

        let asset = AVURLAsset(url: url)

        // Verify asset is readable
        print("🔍 Verifying asset...")
        do {
            let isPlayable = try await asset.load(.isPlayable)
            let duration = try await asset.load(.duration)
            print("✅ Asset is playable: \(isPlayable), duration: \(CMTimeGetSeconds(duration))s")

            if !isPlayable {
                print("❌ Asset is not playable!")
                throw VideoServiceError.invalidVideoURL
            }
        } catch {
            print("❌ Failed to load asset properties: \(error)")
            throw VideoServiceError.invalidVideoURL
        }

        // Create a temporary output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        print("📁 Output URL: \(outputURL)")

        // Use preset-based compression for reliability
        let result = try await compressWithPreset(asset: asset, outputURL: outputURL)

        // Verify output file
        if let attributes = try? FileManager.default.attributesOfItem(atPath: result.path),
           let fileSize = attributes[.size] as? Int64 {
            print("✅ Compressed file size: \(fileSize) bytes")
            if fileSize == 0 {
                print("❌ WARNING: Compressed file is empty!")
                throw VideoServiceError.compressionFailed
            }
        } else {
            print("❌ Cannot read output file attributes")
            throw VideoServiceError.compressionFailed
        }

        return result
    }

    private func compressWithPreset(asset: AVURLAsset, outputURL: URL) async throws -> URL {
        print("🔧 Creating export session with preset: AVAssetExportPresetLowQuality")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality) else {
            print("❌ Failed to create AVAssetExportSession")
            throw VideoServiceError.compressionFailed
        }

        // Delete output file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
            print("🗑️ Removed existing file at output URL")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        print("⏳ Starting export...")

        // Use continuation for iOS 17 compatibility
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                print("📊 Export status: \(exportSession.status.rawValue)")

                switch exportSession.status {
                case .completed:
                    print("✅ Export completed successfully!")
                    continuation.resume(returning: outputURL)
                case .failed:
                    print("❌ Export failed with error: \(exportSession.error?.localizedDescription ?? "unknown")")
                    if let error = exportSession.error {
                        print("❌ Error details: \(error)")
                    }
                    continuation.resume(throwing: exportSession.error ?? VideoServiceError.compressionFailed)
                case .cancelled:
                    print("❌ Export was cancelled")
                    continuation.resume(throwing: VideoServiceError.compressionCancelled)
                default:
                    print("❌ Export finished with unexpected status: \(exportSession.status.rawValue)")
                    continuation.resume(throwing: VideoServiceError.compressionFailed)
                }
            }
        }
    }

    // MARK: - Thumbnail Generation

    func generateThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)

        // For remote URLs, ensure the asset is loaded
        try await asset.load(.duration)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        // Generate thumbnail at 1 second into the video (or at start if video is shorter)
        let duration = try await asset.load(.duration)
        let thumbnailTime = min(CMTime(seconds: 1, preferredTimescale: 60), duration)

        // Use continuation for iOS 17 compatibility
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: thumbnailTime) { cgImage, actualTime, error in
                if let error = error {
                    print("❌ Thumbnail generation error: \(error)")
                    continuation.resume(throwing: error)
                } else if let cgImage = cgImage {
                    print("✅ Generated thumbnail for video")
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    print("❌ No CGImage returned")
                    continuation.resume(throwing: VideoServiceError.thumbnailGenerationFailed)
                }
            }
        }
    }

}

enum VideoServiceError: Error {
    case compressionFailed
    case compressionCancelled
    case thumbnailGenerationFailed
    case invalidVideoURL

    var localizedDescription: String {
        switch self {
        case .compressionFailed:
            return "Failed to compress video"
        case .compressionCancelled:
            return "Video compression was cancelled"
        case .thumbnailGenerationFailed:
            return "Failed to generate video thumbnail"
        case .invalidVideoURL:
            return "Invalid video URL"
        }
    }
}
