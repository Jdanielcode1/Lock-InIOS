//
//  SwiftDataService.swift
//  LockIn
//
//  Service for managing SwiftData local cache
//  Syncs data from Convex subscriptions to local SwiftData store
//

import Foundation
import SwiftData

/// Thread-safe service for managing SwiftData local cache
/// All Convex data flows through this service to populate the local database
@MainActor
final class SwiftDataService {
    static let shared = SwiftDataService()

    private var modelContainer: ModelContainer?

    private init() {}

    /// Configure the service with the model container from the app
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Goals

    /// Sync goals from Convex subscription to SwiftData
    /// Performs upsert: updates existing, inserts new, deletes removed
    func syncGoals(_ goals: [Goal]) async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        // Get IDs from incoming goals
        let incomingIds = Set(goals.map { $0.id })

        // Fetch all existing goals
        let descriptor = FetchDescriptor<SDGoal>()
        let existingGoals = try context.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingGoals.map { ($0.convexId, $0) })

        // Upsert incoming goals
        for goal in goals {
            if let sdGoal = existingMap[goal.id] {
                sdGoal.update(from: goal)
            } else {
                context.insert(SDGoal(from: goal))
            }
        }

        // Delete goals no longer in Convex
        for sdGoal in existingGoals where !incomingIds.contains(sdGoal.convexId) {
            context.delete(sdGoal)
        }

        try context.save()
    }

    /// Fetch all goals from local cache
    func fetchGoals() async throws -> [Goal] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdGoals = try context.fetch(descriptor)
        return sdGoals.map { $0.toGoal() }
    }

    // MARK: - Goal Todos

    /// Sync goal todos from Convex subscription to SwiftData
    func syncGoalTodos(_ goalTodos: [GoalTodo]) async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let incomingIds = Set(goalTodos.map { $0.id })

        let descriptor = FetchDescriptor<SDGoalTodo>()
        let existingTodos = try context.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingTodos.map { ($0.convexId, $0) })

        for goalTodo in goalTodos {
            if let sdTodo = existingMap[goalTodo.id] {
                sdTodo.update(from: goalTodo)
            } else {
                let newTodo = SDGoalTodo(from: goalTodo)

                // Link to parent goal if it exists
                let goalDescriptor = FetchDescriptor<SDGoal>(
                    predicate: #Predicate { $0.convexId == goalTodo.goalId }
                )
                if let parentGoal = try? context.fetch(goalDescriptor).first {
                    newTodo.goal = parentGoal
                }

                context.insert(newTodo)
            }
        }

        // Delete todos no longer in Convex
        for sdTodo in existingTodos where !incomingIds.contains(sdTodo.convexId) {
            context.delete(sdTodo)
        }

        try context.save()
    }

    /// Fetch all goal todos from local cache
    func fetchGoalTodos() async throws -> [GoalTodo] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDGoalTodo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdTodos = try context.fetch(descriptor)
        return sdTodos.map { $0.toGoalTodo() }
    }

    /// Fetch goal todos for a specific goal
    func fetchGoalTodos(for goalId: String) async throws -> [GoalTodo] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDGoalTodo>(
            predicate: #Predicate { $0.goalId == goalId && !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdTodos = try context.fetch(descriptor)
        return sdTodos.map { $0.toGoalTodo() }
    }

    // MARK: - Todo Items (Quick Todos)

    /// Sync todo items from Convex subscription to SwiftData
    func syncTodos(_ todos: [TodoItem]) async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let incomingIds = Set(todos.map { $0.id })

        let descriptor = FetchDescriptor<SDTodoItem>()
        let existingTodos = try context.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingTodos.map { ($0.convexId, $0) })

        for todo in todos {
            if let sdTodo = existingMap[todo.id] {
                sdTodo.update(from: todo)
            } else {
                context.insert(SDTodoItem(from: todo))
            }
        }

        for sdTodo in existingTodos where !incomingIds.contains(sdTodo.convexId) {
            context.delete(sdTodo)
        }

        try context.save()
    }

    /// Fetch all todo items from local cache
    func fetchTodos() async throws -> [TodoItem] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDTodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdTodos = try context.fetch(descriptor)
        return sdTodos.map { $0.toTodoItem() }
    }

    // MARK: - Study Sessions

    /// Sync study sessions from Convex subscription to SwiftData
    func syncStudySessions(_ sessions: [StudySession]) async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let incomingIds = Set(sessions.map { $0.id })

        let descriptor = FetchDescriptor<SDStudySession>()
        let existingSessions = try context.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.convexId, $0) })

        for session in sessions {
            if let sdSession = existingMap[session.id] {
                sdSession.update(from: session)
            } else {
                let newSession = SDStudySession(from: session)

                // Link to parent goal if it exists
                let goalDescriptor = FetchDescriptor<SDGoal>(
                    predicate: #Predicate { $0.convexId == session.goalId }
                )
                if let parentGoal = try? context.fetch(goalDescriptor).first {
                    newSession.goal = parentGoal
                }

                context.insert(newSession)
            }
        }

        for sdSession in existingSessions where !incomingIds.contains(sdSession.convexId) {
            context.delete(sdSession)
        }

        try context.save()
    }

    /// Fetch study sessions for a specific goal
    func fetchStudySessions(for goalId: String) async throws -> [StudySession] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDStudySession>(
            predicate: #Predicate { $0.goalId == goalId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdSessions = try context.fetch(descriptor)
        return sdSessions.map { $0.toStudySession() }
    }

    // MARK: - Partners

    /// Sync partners from Convex subscription to SwiftData
    func syncPartners(_ partners: [Partner]) async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let incomingIds = Set(partners.map { $0.id })

        let descriptor = FetchDescriptor<SDPartner>()
        let existingPartners = try context.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingPartners.map { ($0.convexId, $0) })

        for partner in partners {
            if let sdPartner = existingMap[partner.id] {
                sdPartner.update(from: partner)
            } else {
                context.insert(SDPartner(from: partner))
            }
        }

        for sdPartner in existingPartners where !incomingIds.contains(sdPartner.convexId) {
            context.delete(sdPartner)
        }

        try context.save()
    }

    /// Fetch all partners from local cache
    func fetchPartners() async throws -> [Partner] {
        guard let container = modelContainer else { return [] }
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<SDPartner>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sdPartners = try context.fetch(descriptor)
        return sdPartners.map { $0.toPartner() }
    }

    // MARK: - Cleanup

    /// Clear all cached data for a specific user (called on logout)
    func clearAllData() async throws {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        // Delete all data from each table
        try context.delete(model: SDGoal.self)
        try context.delete(model: SDGoalTodo.self)
        try context.delete(model: SDTodoItem.self)
        try context.delete(model: SDStudySession.self)
        try context.delete(model: SDPartner.self)

        try context.save()
    }
}
