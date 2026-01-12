//
//  SDGoal.swift
//  LockIn
//
//  SwiftData model for local caching of Goal data from Convex
//

import Foundation
import SwiftData

@Model
final class SDGoal {
    @Attribute(.unique) var convexId: String
    var title: String
    var goalDescription: String
    var targetHours: Double
    var completedHours: Double
    var status: String  // "active", "completed", "paused"
    var createdAt: Double
    var lastSyncedAt: Date

    // Relationship to todos
    @Relationship(deleteRule: .cascade, inverse: \SDGoalTodo.goal)
    var todos: [SDGoalTodo] = []

    // Relationship to study sessions
    @Relationship(deleteRule: .cascade, inverse: \SDStudySession.goal)
    var studySessions: [SDStudySession] = []

    init(
        convexId: String,
        title: String,
        goalDescription: String,
        targetHours: Double,
        completedHours: Double,
        status: String,
        createdAt: Double
    ) {
        self.convexId = convexId
        self.title = title
        self.goalDescription = goalDescription
        self.targetHours = targetHours
        self.completedHours = completedHours
        self.status = status
        self.createdAt = createdAt
        self.lastSyncedAt = Date()
    }

    /// Initialize from Convex Goal model
    convenience init(from goal: Goal) {
        self.init(
            convexId: goal.id,
            title: goal.title,
            goalDescription: goal.description,
            targetHours: goal.targetHours,
            completedHours: goal.completedHours,
            status: goal.status.rawValue,
            createdAt: goal.createdAt
        )
    }

    /// Update from Convex Goal model
    func update(from goal: Goal) {
        self.title = goal.title
        self.goalDescription = goal.description
        self.targetHours = goal.targetHours
        self.completedHours = goal.completedHours
        self.status = goal.status.rawValue
        self.lastSyncedAt = Date()
    }

    /// Convert back to Convex Goal model
    func toGoal() -> Goal {
        Goal(
            _id: convexId,
            title: title,
            description: goalDescription,
            targetHours: targetHours,
            completedHours: completedHours,
            status: GoalStatus(rawValue: status) ?? .active,
            createdAt: createdAt
        )
    }
}
