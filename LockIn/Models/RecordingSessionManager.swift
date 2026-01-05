//
//  RecordingSessionManager.swift
//  LockIn
//
//  Manages active recording session state at app level to survive view recreation
//

import SwiftUI

/// Types of recording sessions
enum RecordingSessionType {
    case goalSession(goalId: String, goalTodoId: String?, availableTodos: [GoalTodo])
    case goalTodoRecording(goalTodo: GoalTodo)
    case todoSession(todoIds: Set<String>)
    case todoRecording(todo: TodoItem)
}

/// Manages active recording sessions at the app level
/// This ensures recordings survive view hierarchy recreation during app backgrounding
@MainActor
class RecordingSessionManager: ObservableObject {
    static let shared = RecordingSessionManager()

    /// Whether a recording session is active
    @Published var isRecordingActive = false

    /// The type of active recording session
    @Published var activeSession: RecordingSessionType?

    private init() {}

    // MARK: - Goal Session

    func startGoalSession(goalId: String, goalTodoId: String? = nil, availableTodos: [GoalTodo] = []) {
        activeSession = .goalSession(goalId: goalId, goalTodoId: goalTodoId, availableTodos: availableTodos)
        isRecordingActive = true
    }

    // MARK: - Goal Todo Recording

    func startGoalTodoRecording(goalTodo: GoalTodo) {
        activeSession = .goalTodoRecording(goalTodo: goalTodo)
        isRecordingActive = true
    }

    // MARK: - Todo Session

    func startTodoSession(todoIds: Set<String>) {
        activeSession = .todoSession(todoIds: todoIds)
        isRecordingActive = true
    }

    // MARK: - Single Todo Recording

    func startTodoRecording(todo: TodoItem) {
        activeSession = .todoRecording(todo: todo)
        isRecordingActive = true
    }

    // MARK: - End Session

    func endSession() {
        activeSession = nil
        isRecordingActive = false
    }
}
