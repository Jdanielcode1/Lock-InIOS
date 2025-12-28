//
//  ConvexService.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import ConvexMobile
import ConvexAuth0
import Combine

// Global authenticated Convex client
let convexClient = ConvexClientWithAuth(
    deploymentUrl: "https://tidy-wildcat-344.convex.cloud",
    authProvider: Auth0Provider(enableCachedLogins: true)
)

@MainActor
class ConvexService: ObservableObject {
    static let shared = ConvexService()

    private init() {}

    // MARK: - Goals

    func listGoals() -> AnyPublisher<[Goal], Never> {
        convexClient.subscribe(to: "goals:list", yielding: [Goal].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getGoal(id: String) async throws -> Goal? {
        return try await convexClient.mutation("goals:get", with: ["id": id])
    }

    func createGoal(title: String, description: String, targetHours: Double) async throws -> String {
        return try await convexClient.mutation("goals:create", with: [
            "title": title,
            "description": description,
            "targetHours": targetHours
        ])
    }

    func updateGoalStatus(id: String, status: GoalStatus) async throws {
        let _: String? = try await convexClient.mutation("goals:updateStatus", with: [
            "id": id,
            "status": status.rawValue
        ])
    }

    func deleteGoal(id: String) async throws {
        let _: String? = try await convexClient.mutation("goals:remove", with: ["id": id])
    }

    func archiveGoal(id: String) async throws {
        let _: String? = try await convexClient.mutation("goals:archive", with: ["id": id])
    }

    func unarchiveGoal(id: String) async throws {
        let _: String? = try await convexClient.mutation("goals:unarchive", with: ["id": id])
    }

    func listArchivedGoals() -> AnyPublisher<[Goal], Never> {
        convexClient.subscribe(to: "goals:listArchived", yielding: [Goal].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    // MARK: - Subtasks

    func listSubtasks(goalId: String) -> AnyPublisher<[Subtask], Never> {
        return convexClient.subscribe(to: "subtasks:listByGoal", with: ["goalId": goalId], yielding: [Subtask].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func createSubtask(goalId: String, title: String, description: String, estimatedHours: Double) async throws -> String {
        return try await convexClient.mutation("subtasks:create", with: [
            "goalId": goalId,
            "title": title,
            "description": description,
            "estimatedHours": estimatedHours
        ])
    }

    func deleteSubtask(id: String) async throws {
        let _: String? = try await convexClient.mutation("subtasks:remove", with: ["id": id])
    }

    // MARK: - Study Sessions

    func createStudySession(goalId: String, subtaskId: String?, localVideoPath: String, localThumbnailPath: String?, durationMinutes: Double) async throws -> String {
        if let subtaskId = subtaskId, let thumbnailPath = localThumbnailPath {
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "subtaskId": subtaskId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath,
                "durationMinutes": durationMinutes
            ])
        } else if let subtaskId = subtaskId {
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "subtaskId": subtaskId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        } else if let thumbnailPath = localThumbnailPath {
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath,
                "durationMinutes": durationMinutes
            ])
        } else {
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        }
    }

    func listStudySessions(goalId: String) -> AnyPublisher<[StudySession], Never> {
        return convexClient.subscribe(to: "studySessions:listByGoal", with: ["goalId": goalId], yielding: [StudySession].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func listAllStudySessions() -> AnyPublisher<[StudySession], Never> {
        return convexClient.subscribe(to: "studySessions:listAll", yielding: [StudySession].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func deleteStudySession(id: String, localVideoPath: String, localThumbnailPath: String?) async throws {
        // Delete from Convex
        let _: String? = try await convexClient.mutation("studySessions:remove", with: ["id": id])

        // Delete local files
        LocalStorageService.shared.deleteVideo(at: localVideoPath)
        if let thumbnailPath = localThumbnailPath {
            LocalStorageService.shared.deleteThumbnail(at: thumbnailPath)
        }
    }

    // MARK: - Todos

    func listTodos() -> AnyPublisher<[TodoItem], Never> {
        convexClient.subscribe(to: "todos:list", yielding: [TodoItem].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func createTodo(title: String, description: String?) async throws -> String {
        if let description = description {
            return try await convexClient.mutation("todos:create", with: [
                "title": title,
                "description": description
            ])
        } else {
            return try await convexClient.mutation("todos:create", with: [
                "title": title
            ])
        }
    }

    func toggleTodo(id: String, isCompleted: Bool) async throws {
        let _: String? = try await convexClient.mutation("todos:toggle", with: [
            "id": id,
            "isCompleted": isCompleted
        ])
    }

    func attachVideoToTodo(id: String, localVideoPath: String, localThumbnailPath: String?) async throws {
        if let thumbnailPath = localThumbnailPath {
            let _: String? = try await convexClient.mutation("todos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath
            ])
        } else {
            let _: String? = try await convexClient.mutation("todos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath
            ])
        }
    }

    func attachVideoToMultipleTodos(ids: [String], localVideoPath: String, localThumbnailPath: String?) async throws {
        // Loop through each todo and attach the same video
        for id in ids {
            try await attachVideoToTodo(
                id: id,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath
            )
        }
    }

    func deleteTodo(id: String, localVideoPath: String?, localThumbnailPath: String?) async throws {
        // Delete from Convex
        let _: String? = try await convexClient.mutation("todos:remove", with: ["id": id])

        // Delete local files if they exist
        if let videoPath = localVideoPath {
            LocalStorageService.shared.deleteVideo(at: videoPath)
        }
        if let thumbnailPath = localThumbnailPath {
            LocalStorageService.shared.deleteThumbnail(at: thumbnailPath)
        }
    }

    func archiveTodo(id: String) async throws {
        let _: String? = try await convexClient.mutation("todos:archive", with: ["id": id])
    }

    func unarchiveTodo(id: String) async throws {
        let _: String? = try await convexClient.mutation("todos:unarchive", with: ["id": id])
    }

    func listArchivedTodos() -> AnyPublisher<[TodoItem], Never> {
        convexClient.subscribe(to: "todos:listArchived", yielding: [TodoItem].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
}

enum ConvexServiceError: Error {
    case notFound

    var localizedDescription: String {
        switch self {
        case .notFound:
            return "Resource not found"
        }
    }
}
