//
//  ConvexService.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import ConvexMobile
import Combine

@MainActor
class ConvexService: ObservableObject {
    static let shared = ConvexService()

    // TODO: Replace with your actual Convex deployment URL after running `npx convex dev`
    private let convex = ConvexClient(deploymentUrl: "https://tidy-wildcat-344.convex.cloud")

    private init() {}

    // MARK: - Goals

    func listGoals() -> AnyPublisher<[Goal], Never> {
        convex.subscribe(to: "goals:list", yielding: [Goal].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getGoal(id: String) async throws -> Goal? {
        return try await convex.mutation("goals:get", with: ["id": id])
    }

    func createGoal(title: String, description: String, targetHours: Double) async throws -> String {
        return try await convex.mutation("goals:create", with: [
            "title": title,
            "description": description,
            "targetHours": targetHours
        ])
    }

    func updateGoalStatus(id: String, status: GoalStatus) async throws {
        let _: String? = try await convex.mutation("goals:updateStatus", with: [
            "id": id,
            "status": status.rawValue
        ])
    }

    func deleteGoal(id: String) async throws {
        let _: String? = try await convex.mutation("goals:remove", with: ["id": id])
    }

    // MARK: - Subtasks

    func listSubtasks(goalId: String) -> AnyPublisher<[Subtask], Never> {
        return convex.subscribe(to: "subtasks:listByGoal", with: ["goalId": goalId], yielding: [Subtask].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func createSubtask(goalId: String, title: String, description: String, estimatedHours: Double) async throws -> String {
        return try await convex.mutation("subtasks:create", with: [
            "goalId": goalId,
            "title": title,
            "description": description,
            "estimatedHours": estimatedHours
        ])
    }

    func deleteSubtask(id: String) async throws {
        let _: String? = try await convex.mutation("subtasks:remove", with: ["id": id])
    }

    // MARK: - Study Sessions

    func createStudySession(goalId: String, subtaskId: String?, localVideoPath: String, localThumbnailPath: String?, durationMinutes: Double) async throws -> String {
        if let subtaskId = subtaskId, let thumbnailPath = localThumbnailPath {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "subtaskId": subtaskId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath,
                "durationMinutes": durationMinutes
            ])
        } else if let subtaskId = subtaskId {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "subtaskId": subtaskId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        } else if let thumbnailPath = localThumbnailPath {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath,
                "durationMinutes": durationMinutes
            ])
        } else {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        }
    }

    func listStudySessions(goalId: String) -> AnyPublisher<[StudySession], Never> {
        return convex.subscribe(to: "studySessions:listByGoal", with: ["goalId": goalId], yielding: [StudySession].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func deleteStudySession(id: String, localVideoPath: String, localThumbnailPath: String?) async throws {
        // Delete from Convex
        let _: String? = try await convex.mutation("studySessions:remove", with: ["id": id])

        // Delete local files
        LocalStorageService.shared.deleteVideo(at: localVideoPath)
        if let thumbnailPath = localThumbnailPath {
            LocalStorageService.shared.deleteThumbnail(at: thumbnailPath)
        }
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
