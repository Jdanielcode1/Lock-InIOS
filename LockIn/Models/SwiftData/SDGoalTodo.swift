//
//  SDGoalTodo.swift
//  LockIn
//
//  SwiftData model for local caching of GoalTodo data from Convex
//

import Foundation
import SwiftData

@Model
final class SDGoalTodo {
    @Attribute(.unique) var convexId: String
    var goalId: String
    var title: String
    var todoDescription: String?
    var todoType: String  // "simple", "hours"
    var estimatedHours: Double?
    var completedHours: Double?
    var isCompleted: Bool
    var frequency: String  // "none", "daily", "weekly"
    var lastResetAt: Double?
    var localVideoPath: String?
    var localThumbnailPath: String?
    var videoDurationMinutes: Double?
    var videoNotes: String?
    var isArchived: Bool
    var createdAt: Double
    var goalTitle: String?
    var lastSyncedAt: Date

    // Relationship to parent goal
    var goal: SDGoal?

    init(
        convexId: String,
        goalId: String,
        title: String,
        todoDescription: String?,
        todoType: String,
        estimatedHours: Double?,
        completedHours: Double?,
        isCompleted: Bool,
        frequency: String,
        lastResetAt: Double?,
        localVideoPath: String?,
        localThumbnailPath: String?,
        videoDurationMinutes: Double?,
        videoNotes: String?,
        isArchived: Bool,
        createdAt: Double,
        goalTitle: String?
    ) {
        self.convexId = convexId
        self.goalId = goalId
        self.title = title
        self.todoDescription = todoDescription
        self.todoType = todoType
        self.estimatedHours = estimatedHours
        self.completedHours = completedHours
        self.isCompleted = isCompleted
        self.frequency = frequency
        self.lastResetAt = lastResetAt
        self.localVideoPath = localVideoPath
        self.localThumbnailPath = localThumbnailPath
        self.videoDurationMinutes = videoDurationMinutes
        self.videoNotes = videoNotes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.goalTitle = goalTitle
        self.lastSyncedAt = Date()
    }

    /// Initialize from Convex GoalTodo model
    convenience init(from goalTodo: GoalTodo) {
        self.init(
            convexId: goalTodo.id,
            goalId: goalTodo.goalId,
            title: goalTodo.title,
            todoDescription: goalTodo.description,
            todoType: goalTodo.todoType.rawValue,
            estimatedHours: goalTodo.estimatedHours,
            completedHours: goalTodo.completedHours,
            isCompleted: goalTodo.isCompleted,
            frequency: goalTodo.frequency.rawValue,
            lastResetAt: goalTodo.lastResetAt,
            localVideoPath: goalTodo.localVideoPath,
            localThumbnailPath: goalTodo.localThumbnailPath,
            videoDurationMinutes: goalTodo.videoDurationMinutes,
            videoNotes: goalTodo.videoNotes,
            isArchived: goalTodo.isArchived ?? false,
            createdAt: goalTodo.createdAt,
            goalTitle: goalTodo.goalTitle
        )
    }

    /// Update from Convex GoalTodo model
    func update(from goalTodo: GoalTodo) {
        self.title = goalTodo.title
        self.todoDescription = goalTodo.description
        self.todoType = goalTodo.todoType.rawValue
        self.estimatedHours = goalTodo.estimatedHours
        self.completedHours = goalTodo.completedHours
        self.isCompleted = goalTodo.isCompleted
        self.frequency = goalTodo.frequency.rawValue
        self.lastResetAt = goalTodo.lastResetAt
        self.localVideoPath = goalTodo.localVideoPath
        self.localThumbnailPath = goalTodo.localThumbnailPath
        self.videoDurationMinutes = goalTodo.videoDurationMinutes
        self.videoNotes = goalTodo.videoNotes
        self.isArchived = goalTodo.isArchived ?? false
        self.goalTitle = goalTodo.goalTitle
        self.lastSyncedAt = Date()
    }

    /// Convert back to Convex GoalTodo model
    func toGoalTodo() -> GoalTodo {
        GoalTodo(
            _id: convexId,
            goalId: goalId,
            title: title,
            description: todoDescription,
            todoType: GoalTodoType(rawValue: todoType) ?? .simple,
            estimatedHours: estimatedHours,
            completedHours: completedHours,
            isCompleted: isCompleted,
            frequency: TodoFrequency(rawValue: frequency) ?? .none,
            lastResetAt: lastResetAt,
            localVideoPath: localVideoPath,
            localThumbnailPath: localThumbnailPath,
            videoDurationMinutes: videoDurationMinutes,
            videoNotes: videoNotes,
            isArchived: isArchived,
            createdAt: createdAt,
            goalTitle: goalTitle
        )
    }
}
