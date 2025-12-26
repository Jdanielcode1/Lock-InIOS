//
//  LocalStorageService.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import Foundation
import UIKit

class LocalStorageService {
    static let shared = LocalStorageService()

    private let videosFolder = "LockInVideos"
    private let thumbnailsFolder = "LockInThumbnails"

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Setup

    private func createDirectoriesIfNeeded() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let videosURL = documentsURL.appendingPathComponent(videosFolder)
        let thumbnailsURL = documentsURL.appendingPathComponent(thumbnailsFolder)

        try? FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
    }

    // MARK: - Save Operations

    /// Save video to Documents folder and return relative path
    func saveVideo(from sourceURL: URL) throws -> String {
        let fileName = UUID().uuidString + ".mp4"
        let relativePath = "\(videosFolder)/\(fileName)"

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw LocalStorageError.documentsNotFound
        }

        let destinationURL = documentsURL.appendingPathComponent(relativePath)

        // Remove existing file if any
        try? FileManager.default.removeItem(at: destinationURL)

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        print("📁 Video saved to: \(destinationURL.path)")
        return relativePath
    }

    /// Save thumbnail image and return relative path
    func saveThumbnail(_ image: UIImage) throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        let relativePath = "\(thumbnailsFolder)/\(fileName)"

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw LocalStorageError.documentsNotFound
        }

        let destinationURL = documentsURL.appendingPathComponent(relativePath)

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw LocalStorageError.thumbnailSaveFailed
        }

        try jpegData.write(to: destinationURL)

        print("📁 Thumbnail saved to: \(destinationURL.path)")
        return relativePath
    }

    // MARK: - Delete Operations

    /// Delete video file at relative path
    func deleteVideo(at relativePath: String) {
        guard let url = getFullURL(for: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
        print("🗑️ Video deleted: \(relativePath)")
    }

    /// Delete thumbnail file at relative path
    func deleteThumbnail(at relativePath: String) {
        guard let url = getFullURL(for: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
        print("🗑️ Thumbnail deleted: \(relativePath)")
    }

    // MARK: - Utility

    /// Get full URL for a relative path
    func getFullURL(for relativePath: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(relativePath)
    }

    /// Check if file exists at relative path
    func fileExists(at relativePath: String) -> Bool {
        guard let url = getFullURL(for: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

enum LocalStorageError: Error, LocalizedError {
    case documentsNotFound
    case thumbnailSaveFailed
    case videoSaveFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .documentsNotFound:
            return "Could not access Documents directory"
        case .thumbnailSaveFailed:
            return "Failed to save thumbnail"
        case .videoSaveFailed:
            return "Failed to save video"
        case .fileNotFound:
            return "File not found"
        }
    }
}
