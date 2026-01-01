//
//  TodoItem.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import Foundation

struct TodoItem: Identifiable, Codable {
    let _id: String
    var title: String
    var description: String?
    var isCompleted: Bool
    var localVideoPath: String?
    var localThumbnailPath: String?
    var videoNotes: String?
    var speedSegmentsJSON: String?
    let createdAt: Double

    var id: String { _id }

    // Computed property to get the video URL
    var videoURL: URL? {
        guard let path = localVideoPath else { return nil }
        return LocalStorageService.shared.getFullURL(for: path)
    }

    // Computed property to get the thumbnail URL
    var thumbnailURL: URL? {
        guard let path = localThumbnailPath else { return nil }
        return LocalStorageService.shared.getFullURL(for: path)
    }

    // Check if todo has video attached
    var hasVideo: Bool {
        localVideoPath != nil
    }

    // Created date for display
    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000)
    }

    // Parse speed segments from JSON for accurate stopwatch calculation
    var speedSegments: [SpeedSegment]? {
        TimeLapseRecorder.parseSpeedSegments(from: speedSegmentsJSON)
    }
}

// For creating new todos (without ID)
struct CreateTodoRequest: Codable {
    let title: String
    let description: String?
}
