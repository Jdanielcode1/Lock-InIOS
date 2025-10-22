//
//  Goal.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation

struct Goal: Identifiable, Codable {
    let _id: String
    var title: String
    var description: String
    var targetHours: Double
    var completedHours: Double
    var status: GoalStatus
    let createdAt: Double

    var id: String { _id }

    var progressPercentage: Double {
        guard targetHours > 0 else { return 0 }
        return min((completedHours / targetHours) * 100, 100)
    }

    var hoursRemaining: Double {
        max(targetHours - completedHours, 0)
    }

    var isCompleted: Bool {
        status == .completed
    }
}

enum GoalStatus: String, Codable {
    case active
    case completed
    case paused

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .paused: return "Paused"
        }
    }
}

// For creating new goals (without ID)
struct CreateGoalRequest: Codable {
    let title: String
    let description: String
    let targetHours: Double
}
