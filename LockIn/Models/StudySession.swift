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
    let videoStorageId: String
    let thumbnailStorageId: String?
    let durationMinutes: Double
    let uploadedAt: Double

    var id: String { _id }

    var durationHours: Double {
        durationMinutes / 60
    }

    var uploadedDate: Date {
        Date(timeIntervalSince1970: uploadedAt / 1000)
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
    let videoStorageId: String
    let thumbnailStorageId: String?
    let durationMinutes: Double
}
