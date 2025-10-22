//
//  Subtask.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation

struct Subtask: Identifiable, Codable {
    let _id: String
    let goalId: String
    var title: String
    var description: String
    var estimatedHours: Double
    var completedHours: Double
    let createdAt: Double

    var id: String { _id }

    var progressPercentage: Double {
        guard estimatedHours > 0 else { return 0 }
        return min((completedHours / estimatedHours) * 100, 100)
    }

    var hoursRemaining: Double {
        max(estimatedHours - completedHours, 0)
    }

    var isCompleted: Bool {
        completedHours >= estimatedHours
    }
}

// For creating new subtasks (without ID)
struct CreateSubtaskRequest: Codable {
    let goalId: String
    let title: String
    let description: String
    let estimatedHours: Double
}
