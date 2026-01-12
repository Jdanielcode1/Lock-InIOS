//
//  SDStudySession.swift
//  LockIn
//
//  SwiftData model for local caching of StudySession data from Convex
//

import Foundation
import SwiftData

@Model
final class SDStudySession {
    @Attribute(.unique) var convexId: String
    var goalId: String
    var goalTodoId: String?
    var localVideoPath: String
    var localThumbnailPath: String?
    var durationMinutes: Double
    var notes: String?
    var createdAt: Double
    var lastSyncedAt: Date

    // Relationship to parent goal
    var goal: SDGoal?

    init(
        convexId: String,
        goalId: String,
        goalTodoId: String?,
        localVideoPath: String,
        localThumbnailPath: String?,
        durationMinutes: Double,
        notes: String?,
        createdAt: Double
    ) {
        self.convexId = convexId
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        self.localVideoPath = localVideoPath
        self.localThumbnailPath = localThumbnailPath
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.createdAt = createdAt
        self.lastSyncedAt = Date()
    }

    /// Initialize from Convex StudySession model
    convenience init(from session: StudySession) {
        self.init(
            convexId: session.id,
            goalId: session.goalId,
            goalTodoId: session.goalTodoId,
            localVideoPath: session.localVideoPath,
            localThumbnailPath: session.localThumbnailPath,
            durationMinutes: session.durationMinutes,
            notes: session.notes,
            createdAt: session.createdAt
        )
    }

    /// Update from Convex StudySession model
    func update(from session: StudySession) {
        self.goalTodoId = session.goalTodoId
        self.localVideoPath = session.localVideoPath
        self.localThumbnailPath = session.localThumbnailPath
        self.durationMinutes = session.durationMinutes
        self.notes = session.notes
        self.lastSyncedAt = Date()
    }

    /// Convert back to Convex StudySession model
    func toStudySession() -> StudySession {
        StudySession(
            _id: convexId,
            goalId: goalId,
            goalTodoId: goalTodoId,
            localVideoPath: localVideoPath,
            localThumbnailPath: localThumbnailPath,
            durationMinutes: durationMinutes,
            notes: notes,
            createdAt: createdAt
        )
    }
}
