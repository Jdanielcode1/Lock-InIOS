//
//  BackgroundUploadManager.swift
//  LockIn
//
//  Manages background video uploads to partners
//

import Foundation
import UIKit

/// Metadata for a video upload
struct UploadMetadata: Codable {
    let id: UUID
    let videoPath: String
    let thumbnailPath: String?
    let partnerIds: [String]
    let durationMinutes: Double
    let goalTitle: String?
    let todoTitle: String?
    let notes: String?
    let createdAt: Date
}

/// Status of an upload task
enum UploadStatus: Equatable {
    case pending
    case uploading(progress: Double)
    case completed
    case failed(message: String)
}

/// An upload task
struct UploadTask: Identifiable {
    let id: UUID
    let metadata: UploadMetadata
    var status: UploadStatus

    var fileName: String {
        URL(fileURLWithPath: metadata.videoPath).lastPathComponent
    }
}

/// Manages background video uploads
@MainActor
class BackgroundUploadManager: NSObject, ObservableObject {
    static let shared = BackgroundUploadManager()

    @Published var activeUploads: [UploadTask] = []
    @Published var recentCompletions: [UploadTask] = []

    private var pendingUploads: [UUID: UploadMetadata] = [:]
    private let fileManager = FileManager.default
    private let uploadQueue = DispatchQueue(label: "com.lockin.upload", qos: .background)

    private override init() {
        super.init()
        loadPendingUploads()
    }

    // MARK: - Public API

    /// Enqueue a video for background upload
    func enqueueUpload(
        videoURL: URL,
        thumbnailURL: URL?,
        partnerIds: [String],
        durationMinutes: Double,
        goalTitle: String?,
        todoTitle: String?,
        notes: String?
    ) {
        let uploadId = UUID()

        // Copy video to persistent location
        let uploadDir = getUploadDirectory()
        let videoDestination = uploadDir.appendingPathComponent("\(uploadId.uuidString).mov")

        var thumbnailDestination: URL? = nil
        if let thumbURL = thumbnailURL {
            thumbnailDestination = uploadDir.appendingPathComponent("\(uploadId.uuidString)_thumb.jpg")
            try? fileManager.copyItem(at: thumbURL, to: thumbnailDestination!)
        }

        do {
            try fileManager.copyItem(at: videoURL, to: videoDestination)
        } catch {
            print("Failed to copy video for upload: \(error)")
            return
        }

        let metadata = UploadMetadata(
            id: uploadId,
            videoPath: videoDestination.path,
            thumbnailPath: thumbnailDestination?.path,
            partnerIds: partnerIds,
            durationMinutes: durationMinutes,
            goalTitle: goalTitle,
            todoTitle: todoTitle,
            notes: notes,
            createdAt: Date()
        )

        // Save metadata for persistence
        pendingUploads[uploadId] = metadata
        savePendingUploads()

        // Create task
        let task = UploadTask(id: uploadId, metadata: metadata, status: .pending)
        activeUploads.append(task)

        // Start upload
        startUpload(metadata)

        // Show toast
        ToastManager.shared.showUploadStarted()
    }

    /// Retry a failed upload
    func retryUpload(_ uploadId: UUID) {
        guard let metadata = pendingUploads[uploadId] else { return }

        // Update status
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].status = .pending
        }

        startUpload(metadata)
    }

    /// Cancel an upload
    func cancelUpload(_ uploadId: UUID) {
        // Remove from pending
        pendingUploads.removeValue(forKey: uploadId)
        savePendingUploads()

        // Remove from active
        activeUploads.removeAll { $0.id == uploadId }

        // Clean up files
        cleanupUploadFiles(uploadId)
    }

    // MARK: - Upload Logic

    private func startUpload(_ metadata: UploadMetadata) {
        updateStatus(metadata.id, .uploading(progress: 0))

        Task {
            do {
                // Step 1: Generate upload URL for video
                let r2Response = try await ConvexService.shared.generateUploadUrl()

                // Step 2: Upload video file
                let videoURL = URL(fileURLWithPath: metadata.videoPath)
                let videoData = try Data(contentsOf: videoURL)

                var request = URLRequest(url: URL(string: r2Response.url)!)
                request.httpMethod = "PUT"
                request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")

                updateStatus(metadata.id, .uploading(progress: 0.3))

                let (_, response) = try await URLSession.shared.upload(for: request, from: videoData)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw UploadError.uploadFailed
                }

                updateStatus(metadata.id, .uploading(progress: 0.6))

                // Step 3: Upload thumbnail if exists
                var thumbnailR2Key: String? = nil
                if let thumbPath = metadata.thumbnailPath {
                    let thumbURL = URL(fileURLWithPath: thumbPath)
                    if let thumbData = try? Data(contentsOf: thumbURL) {
                        let thumbR2Response = try await ConvexService.shared.generateUploadUrl()

                        var thumbRequest = URLRequest(url: URL(string: thumbR2Response.url)!)
                        thumbRequest.httpMethod = "PUT"
                        thumbRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

                        let (_, thumbResp) = try await URLSession.shared.upload(for: thumbRequest, from: thumbData)
                        if let httpResp = thumbResp as? HTTPURLResponse, httpResp.statusCode == 200 {
                            thumbnailR2Key = thumbR2Response.key
                            try await ConvexService.shared.syncR2Metadata(key: thumbR2Response.key)
                        }
                    }
                }

                updateStatus(metadata.id, .uploading(progress: 0.8))

                // Step 4: Sync metadata and create shared video record
                try await ConvexService.shared.syncR2Metadata(key: r2Response.key)

                _ = try await ConvexService.shared.shareVideo(
                    r2Key: r2Response.key,
                    thumbnailR2Key: thumbnailR2Key,
                    durationMinutes: metadata.durationMinutes,
                    goalTitle: metadata.goalTitle,
                    todoTitle: metadata.todoTitle,
                    notes: metadata.notes,
                    partnerIds: metadata.partnerIds
                )

                // Success!
                await MainActor.run {
                    updateStatus(metadata.id, .completed)
                    pendingUploads.removeValue(forKey: metadata.id)
                    savePendingUploads()
                    cleanupUploadFiles(metadata.id)

                    // Move to completed
                    if let index = activeUploads.firstIndex(where: { $0.id == metadata.id }) {
                        let completed = activeUploads.remove(at: index)
                        recentCompletions.append(completed)

                        // Auto-remove from completions after delay
                        Task {
                            try? await Task.sleep(for: .seconds(5))
                            await MainActor.run {
                                recentCompletions.removeAll { $0.id == metadata.id }
                            }
                        }
                    }

                    ToastManager.shared.showUploadComplete()
                    HapticFeedback.success()
                }

            } catch {
                await MainActor.run {
                    let message = error.localizedDescription
                    updateStatus(metadata.id, .failed(message: message))
                    ToastManager.shared.showUploadFailed { [weak self] in
                        self?.retryUpload(metadata.id)
                    }
                    HapticFeedback.error()
                }
            }
        }
    }

    private func updateStatus(_ uploadId: UUID, _ status: UploadStatus) {
        if let index = activeUploads.firstIndex(where: { $0.id == uploadId }) {
            activeUploads[index].status = status
        }
    }

    // MARK: - Persistence

    private func getUploadDirectory() -> URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let uploadDir = documentsDir.appendingPathComponent("PendingUploads")

        if !fileManager.fileExists(atPath: uploadDir.path) {
            try? fileManager.createDirectory(at: uploadDir, withIntermediateDirectories: true)
        }

        return uploadDir
    }

    private func savePendingUploads() {
        let metadataArray = Array(pendingUploads.values)
        if let data = try? JSONEncoder().encode(metadataArray) {
            let url = getUploadDirectory().appendingPathComponent("pending.json")
            try? data.write(to: url)
        }
    }

    private func loadPendingUploads() {
        let url = getUploadDirectory().appendingPathComponent("pending.json")
        guard let data = try? Data(contentsOf: url),
              let metadataArray = try? JSONDecoder().decode([UploadMetadata].self, from: data) else {
            return
        }

        for metadata in metadataArray {
            pendingUploads[metadata.id] = metadata

            // Recreate tasks for any pending uploads
            let task = UploadTask(id: metadata.id, metadata: metadata, status: .pending)
            activeUploads.append(task)

            // Restart uploads
            startUpload(metadata)
        }
    }

    private func cleanupUploadFiles(_ uploadId: UUID) {
        let uploadDir = getUploadDirectory()
        let videoPath = uploadDir.appendingPathComponent("\(uploadId.uuidString).mov")
        let thumbPath = uploadDir.appendingPathComponent("\(uploadId.uuidString)_thumb.jpg")

        try? fileManager.removeItem(at: videoPath)
        try? fileManager.removeItem(at: thumbPath)
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case uploadFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Upload failed. Please try again."
        case .networkError:
            return "Network error. Check your connection."
        }
    }
}
