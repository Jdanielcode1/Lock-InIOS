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
    private let convex = ConvexClient(deploymentUrl: "https://grateful-poodle-804.convex.cloud")

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

    func generateUploadUrl() async throws -> String {
        return try await convex.mutation("studySessions:generateUploadUrl")
    }

    func uploadVideo(url: URL, uploadUrl: String) async throws -> String {
        print("📤 Starting upload to: \(uploadUrl)")

        // Check file before upload
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            print("📦 Uploading file size: \(fileSize) bytes")
        }

        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // 5 minutes timeout for large video uploads
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

        // Create custom URLSession with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)

        let videoData = try Data(contentsOf: url)
        print("📦 Video data loaded: \(videoData.count) bytes")

        let (data, response) = try await session.upload(for: request, from: videoData)

        print("📡 Upload response received")

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConvexServiceError.uploadFailed
        }

        // Parse the storage ID from the response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let storageId = json["storageId"] as? String {
            return storageId
        }

        throw ConvexServiceError.invalidResponse
    }

    func createStudySession(goalId: String, subtaskId: String?, videoStorageId: String, durationMinutes: Double) async throws -> String {
        if let subtaskId = subtaskId {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "subtaskId": subtaskId,
                "videoStorageId": videoStorageId,
                "durationMinutes": durationMinutes
            ])
        } else {
            return try await convex.mutation("studySessions:create", with: [
                "goalId": goalId,
                "videoStorageId": videoStorageId,
                "durationMinutes": durationMinutes
            ])
        }
    }

    func listStudySessions(goalId: String) -> AnyPublisher<[StudySession], Never> {
        return convex.subscribe(to: "studySessions:listByGoal", with: ["goalId": goalId], yielding: [StudySession].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getVideoUrl(storageId: String) async throws -> String? {
        return try await convex.mutation("studySessions:getVideoUrl", with: ["storageId": storageId])
    }

    func deleteStudySession(id: String) async throws {
        let _: String? = try await convex.mutation("studySessions:remove", with: ["id": id])
    }
}

enum ConvexServiceError: Error {
    case uploadFailed
    case invalidResponse
    case notFound

    var localizedDescription: String {
        switch self {
        case .uploadFailed:
            return "Failed to upload video"
        case .invalidResponse:
            return "Invalid response from server"
        case .notFound:
            return "Resource not found"
        }
    }
}
