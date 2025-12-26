//
//  StudySession.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation

struct StudySession: Identifiable, Codable {
    let _id: String
    let goalId: String
    let subtaskId: String?
    let localVideoPath: String
    let localThumbnailPath: String?
    let durationMinutes: Double
    let createdAt: Double

    var id: String { _id }

    var durationHours: Double {
        durationMinutes / 60
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000)
    }

    var videoURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(localVideoPath)
    }

    var thumbnailURL: URL? {
        guard let thumbnailPath = localThumbnailPath else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(thumbnailPath)
    }

    var formattedDuration: String {
        let hours = Int(durationMinutes / 60)
        let minutes = Int(durationMinutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// For creating new study sessions (without ID)
struct CreateStudySessionRequest: Codable {
    let goalId: String
    let subtaskId: String?
    let localVideoPath: String
    let localThumbnailPath: String?
    let durationMinutes: Double
}
