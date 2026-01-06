//
//  VideoPlayerSessionManager.swift
//  LockIn
//
//  Manages active video playback session state at app level to survive view recreation
//

import SwiftUI

/// Types of video playback sessions
enum VideoPlaybackSessionType {
    case studySession(session: StudySession, onResume: (() -> Void)?)
    case todoVideo(todo: TodoItem, videoURL: URL, onResume: (() -> Void)?)
    case goalTodoVideo(goalTodo: GoalTodo, videoURL: URL, onResume: (() -> Void)?)
}

/// Manages active video playback sessions at the app level
/// This ensures video players survive view hierarchy recreation during app backgrounding
@MainActor
class VideoPlayerSessionManager: ObservableObject {
    static let shared = VideoPlayerSessionManager()

    /// Whether a video playback session is active
    @Published var isPlaybackActive = false

    /// The type of active playback session
    @Published var activeSession: VideoPlaybackSessionType?

    private init() {}

    // MARK: - Study Session Video

    func playStudySession(_ session: StudySession, onResume: (() -> Void)? = nil) {
        activeSession = .studySession(session: session, onResume: onResume)
        isPlaybackActive = true
    }

    // MARK: - Todo Video

    func playTodoVideo(todo: TodoItem, videoURL: URL, onResume: (() -> Void)? = nil) {
        activeSession = .todoVideo(todo: todo, videoURL: videoURL, onResume: onResume)
        isPlaybackActive = true
    }

    // MARK: - Goal Todo Video

    func playGoalTodoVideo(goalTodo: GoalTodo, videoURL: URL, onResume: (() -> Void)? = nil) {
        activeSession = .goalTodoVideo(goalTodo: goalTodo, videoURL: videoURL, onResume: onResume)
        isPlaybackActive = true
    }

    // MARK: - End Playback

    func endPlayback() {
        activeSession = nil
        isPlaybackActive = false
    }
}
