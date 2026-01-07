//
//  RecordingSessionManager.swift
//  LockIn
//
//  Manages active recording session state at app level to survive view recreation
//

import SwiftUI

/// Data needed to continue/append to an existing recording
struct ContinueRecordingData {
    let videoURL: URL
    let speedSegmentsJSON: String?
    let duration: TimeInterval
    let notes: String?
}

/// Types of recording sessions
enum RecordingSessionType {
    case goalSession(goalId: String, goalTodoId: String?, availableTodos: [GoalTodo], continueFrom: ContinueRecordingData?)
    case goalTodoRecording(goalTodo: GoalTodo, continueFrom: ContinueRecordingData?)
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

    func startGoalSession(goalId: String, goalTodoId: String? = nil, availableTodos: [GoalTodo] = [], continueFrom: ContinueRecordingData? = nil) {
        activeSession = .goalSession(goalId: goalId, goalTodoId: goalTodoId, availableTodos: availableTodos, continueFrom: continueFrom)
        isRecordingActive = true
    }

    // MARK: - Goal Todo Recording

    func startGoalTodoRecording(goalTodo: GoalTodo, continueFrom: ContinueRecordingData? = nil) {
        activeSession = .goalTodoRecording(goalTodo: goalTodo, continueFrom: continueFrom)
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
