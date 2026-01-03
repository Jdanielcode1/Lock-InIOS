//
//  SharedVideo.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import Foundation

struct SharedVideo: Identifiable, Codable {
    let _id: String
    let userId: String
    let r2Key: String
    let thumbnailR2Key: String?
    let durationMinutes: Double
    let goalTitle: String?
    let todoTitle: String?
    let notes: String?
    let sharedWithPartnerIds: [String]
    let createdAt: Double

    var id: String { _id }

    var formattedDuration: String {
        let totalSeconds = Int(durationMinutes * 60)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000)
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdDate, relativeTo: Date())
    }

    var contextDescription: String {
        if let goal = goalTitle, let todo = todoTitle {
            return "\(goal) • \(todo)"
        } else if let goal = goalTitle {
            return goal
        } else if let todo = todoTitle {
            return todo
        }
        return "Study session"
    }
}
