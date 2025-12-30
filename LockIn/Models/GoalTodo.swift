//
//  GoalTodo.swift
//  LockIn
//
//  Created by Claude on 29/12/25.
//

import Foundation

enum GoalTodoType: String, Codable, CaseIterable {
    case simple = "simple"
    case hours = "hours"

    var displayName: String {
        switch self {
        case .simple: return "Checkbox"
        case .hours: return "Hours-based"
        }
    }

    var icon: String {
        switch self {
        case .simple: return "checkmark.circle"
        case .hours: return "clock"
        }
    }
}

enum TodoFrequency: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"

    var displayName: String {
        switch self {
        case .none: return "One-time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle"
        case .daily: return "sun.max"
        case .weekly: return "calendar.badge.clock"
        }
    }
}

struct GoalTodo: Identifiable, Codable {
    let _id: String
    let goalId: String
    var title: String
    var description: String?
    var todoType: GoalTodoType
    var estimatedHours: Double?
    var completedHours: Double?
    var isCompleted: Bool
    var frequency: TodoFrequency
    var lastResetAt: Double?
    var localVideoPath: String?
    var localThumbnailPath: String?
    let createdAt: Double
    // Goal title - included when fetching all todos for the user
    var goalTitle: String?

    var id: String { _id }

    // For hours-based todos
    var progressPercentage: Double {
        guard todoType == .hours,
              let estimated = estimatedHours, estimated > 0,
              let completed = completedHours else { return 0 }
        return min((completed / estimated) * 100, 100)
    }

    var hoursRemaining: Double {
        guard let estimated = estimatedHours, let completed = completedHours else { return 0 }
        return max(estimated - completed, 0)
    }

    var isHoursCompleted: Bool {
        guard todoType == .hours else { return isCompleted }
        guard let estimated = estimatedHours, let completed = completedHours else { return false }
        return completed >= estimated
    }

    var hasVideo: Bool {
        localVideoPath != nil
    }

    var videoURL: URL? {
        guard let path = localVideoPath else { return nil }
        return LocalStorageService.shared.getFullURL(for: path)
    }

    var thumbnailURL: URL? {
        guard let path = localThumbnailPath else { return nil }
        return LocalStorageService.shared.getFullURL(for: path)
    }

    var isRecurring: Bool {
        frequency != .none
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000)
    }
}

// For creating new goal todos (without ID)
struct CreateGoalTodoRequest: Codable {
    let goalId: String
    let title: String
    let description: String?
    let todoType: GoalTodoType
    let estimatedHours: Double?
    let frequency: TodoFrequency
}
