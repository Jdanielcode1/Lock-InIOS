//
//  ConvexService.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import ConvexMobile
import Combine

// Firebase auth provider instance (shared for token management)
let firebaseAuthProvider = FirebaseAuthProvider()

// Global authenticated Convex client
let convexClient = ConvexClientWithAuth(
    deploymentUrl: "https://tidy-wildcat-344.convex.cloud",
    authProvider: firebaseAuthProvider
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

    func subscribeToGoal(id: String) -> AnyPublisher<Goal?, Never> {
        convexClient.subscribe(to: "goals:get", with: ["id": id], yielding: Goal?.self)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }

    func getGoal(id: String) async throws -> Goal? {
        return try await convexClient.action("goals:get", with: ["id": id])
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

    func updateGoalTitle(id: String, title: String) async throws {
        let _: String? = try await convexClient.mutation("goals:updateTitle", with: [
            "id": id,
            "title": title
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

    // MARK: - Goal Todos

    func listGoalTodos(goalId: String) -> AnyPublisher<[GoalTodo], Never> {
        return convexClient.subscribe(to: "goalTodos:listByGoal", with: ["goalId": goalId], yielding: [GoalTodo].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func listAllGoalTodos() -> AnyPublisher<[GoalTodo], Never> {
        return convexClient.subscribe(to: "goalTodos:listAll", yielding: [GoalTodo].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func createGoalTodo(
        goalId: String,
        title: String,
        description: String?,
        todoType: GoalTodoType,
        estimatedHours: Double?,
        frequency: TodoFrequency
    ) async throws -> String {
        // Handle all combinations of optional parameters
        if let desc = description, let hours = estimatedHours, todoType == .hours {
            return try await convexClient.mutation("goalTodos:create", with: [
                "goalId": goalId,
                "title": title,
                "description": desc,
                "todoType": todoType.rawValue,
                "estimatedHours": hours,
                "frequency": frequency.rawValue
            ])
        } else if let desc = description {
            return try await convexClient.mutation("goalTodos:create", with: [
                "goalId": goalId,
                "title": title,
                "description": desc,
                "todoType": todoType.rawValue,
                "frequency": frequency.rawValue
            ])
        } else if let hours = estimatedHours, todoType == .hours {
            return try await convexClient.mutation("goalTodos:create", with: [
                "goalId": goalId,
                "title": title,
                "todoType": todoType.rawValue,
                "estimatedHours": hours,
                "frequency": frequency.rawValue
            ])
        } else {
            return try await convexClient.mutation("goalTodos:create", with: [
                "goalId": goalId,
                "title": title,
                "todoType": todoType.rawValue,
                "frequency": frequency.rawValue
            ])
        }
    }

    func toggleGoalTodo(id: String, isCompleted: Bool) async throws {
        let _: String? = try await convexClient.mutation("goalTodos:toggle", with: [
            "id": id,
            "isCompleted": isCompleted
        ])
    }

    func deleteGoalTodo(id: String) async throws {
        let _: String? = try await convexClient.mutation("goalTodos:remove", with: ["id": id])
    }

    func attachVideoToGoalTodo(id: String, localVideoPath: String, localThumbnailPath: String?, videoDurationMinutes: Double?, videoNotes: String? = nil) async throws {
        // Handle all combinations of optional parameters explicitly
        let hasThumb = localThumbnailPath != nil
        let hasDuration = videoDurationMinutes != nil
        let hasNotes = videoNotes != nil && !videoNotes!.isEmpty

        switch (hasThumb, hasDuration, hasNotes) {
        case (true, true, true):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "videoDurationMinutes": videoDurationMinutes!,
                "videoNotes": videoNotes!
            ])
        case (true, true, false):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "videoDurationMinutes": videoDurationMinutes!
            ])
        case (true, false, true):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "videoNotes": videoNotes!
            ])
        case (true, false, false):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!
            ])
        case (false, true, true):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "videoDurationMinutes": videoDurationMinutes!,
                "videoNotes": videoNotes!
            ])
        case (false, true, false):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "videoDurationMinutes": videoDurationMinutes!
            ])
        case (false, false, true):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "videoNotes": videoNotes!
            ])
        case (false, false, false):
            let _: String? = try await convexClient.mutation("goalTodos:attachVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath
            ])
        }
    }

    func updateGoalTodoVideoNotes(todoId: String, videoNotes: String?) async throws {
        if let notes = videoNotes {
            let _: String? = try await convexClient.mutation("goalTodos:updateVideoNotes", with: [
                "id": todoId,
                "videoNotes": notes
            ])
        } else {
            let _: String? = try await convexClient.mutation("goalTodos:updateVideoNotes", with: [
                "id": todoId
            ])
        }
    }

    func archiveGoalTodo(id: String) async throws {
        let _: String? = try await convexClient.mutation("goalTodos:archive", with: ["id": id])
    }

    func unarchiveGoalTodo(id: String) async throws {
        let _: String? = try await convexClient.mutation("goalTodos:unarchive", with: ["id": id])
    }

    func checkAndResetRecurringTodos(goalId: String) async throws {
        let _: String? = try await convexClient.mutation("goalTodos:checkAndResetRecurring", with: [
            "goalId": goalId
        ])
    }

    // MARK: - Study Sessions

    func createStudySession(goalId: String, goalTodoId: String?, localVideoPath: String, localThumbnailPath: String?, durationMinutes: Double, notes: String? = nil) async throws -> String {
        // Handle all combinations of optional parameters explicitly
        let hasTodo = goalTodoId != nil
        let hasThumb = localThumbnailPath != nil
        let hasNotes = notes != nil && !notes!.isEmpty

        switch (hasTodo, hasThumb, hasNotes) {
        case (true, true, true):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "goalTodoId": goalTodoId!,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "durationMinutes": durationMinutes,
                "notes": notes!
            ])
        case (true, true, false):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "goalTodoId": goalTodoId!,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "durationMinutes": durationMinutes
            ])
        case (true, false, true):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "goalTodoId": goalTodoId!,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes,
                "notes": notes!
            ])
        case (true, false, false):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "goalTodoId": goalTodoId!,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        case (false, true, true):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "durationMinutes": durationMinutes,
                "notes": notes!
            ])
        case (false, true, false):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": localThumbnailPath!,
                "durationMinutes": durationMinutes
            ])
        case (false, false, true):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes,
                "notes": notes!
            ])
        case (false, false, false):
            return try await convexClient.mutation("studySessions:create", with: [
                "goalId": goalId,
                "localVideoPath": localVideoPath,
                "durationMinutes": durationMinutes
            ])
        }
    }

    func updateStudySessionNotes(sessionId: String, notes: String?) async throws {
        if let notes = notes {
            let _: String? = try await convexClient.mutation("studySessions:updateNotes", with: [
                "id": sessionId,
                "notes": notes
            ])
        } else {
            let _: String? = try await convexClient.mutation("studySessions:updateNotes", with: [
                "id": sessionId
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

    func updateStudySessionVideo(id: String, localVideoPath: String, localThumbnailPath: String?) async throws {
        if let thumbnailPath = localThumbnailPath {
            let _: String? = try await convexClient.mutation("studySessions:updateVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath,
                "localThumbnailPath": thumbnailPath
            ])
        } else {
            let _: String? = try await convexClient.mutation("studySessions:updateVideo", with: [
                "id": id,
                "localVideoPath": localVideoPath
            ])
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

    func updateTodo(id: String, title: String, description: String?) async throws {
        if let desc = description {
            let _: String? = try await convexClient.mutation("todos:update", with: [
                "id": id,
                "title": title,
                "description": desc
            ])
        } else {
            let _: String? = try await convexClient.mutation("todos:update", with: [
                "id": id,
                "title": title
            ])
        }
    }

    func attachVideoToTodo(id: String, localVideoPath: String, localThumbnailPath: String?, videoNotes: String? = nil, speedSegmentsJSON: String? = nil) async throws {
        // Build args dictionary dynamically to handle optional parameters
        var args: [String: ConvexEncodable] = [
            "id": id,
            "localVideoPath": localVideoPath
        ]

        if let thumb = localThumbnailPath {
            args["localThumbnailPath"] = thumb
        }
        if let notes = videoNotes, !notes.isEmpty {
            args["videoNotes"] = notes
        }
        if let segments = speedSegmentsJSON {
            args["speedSegmentsJSON"] = segments
        }

        let _: String? = try await convexClient.mutation("todos:attachVideo", with: args)
    }

    func attachVideoToMultipleTodos(ids: [String], localVideoPath: String, localThumbnailPath: String?, videoNotes: String? = nil, speedSegmentsJSON: String? = nil) async throws {
        // Loop through each todo and attach the same video
        for id in ids {
            try await attachVideoToTodo(
                id: id,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath,
                videoNotes: videoNotes,
                speedSegmentsJSON: speedSegmentsJSON
            )
        }
    }

    func updateTodoVideoNotes(todoId: String, videoNotes: String?) async throws {
        if let notes = videoNotes {
            let _: String? = try await convexClient.mutation("todos:updateVideoNotes", with: [
                "id": todoId,
                "videoNotes": notes
            ])
        } else {
            let _: String? = try await convexClient.mutation("todos:updateVideoNotes", with: [
                "id": todoId
            ])
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

    // MARK: - Paginated Actions (ConvexMobile doesn't have .query, so we use action wrappers)
    // Note: Convex v.number() expects float64, so we cast Int to Double

    func listAllStudySessionsPaginated(cursor: String? = nil, numItems: Int = 20) async throws -> PaginatedStudySessions {
        if let cursor = cursor {
            return try await convexClient.action("studySessions:fetchAllPaginated", with: [
                "numItems": Double(numItems),
                "cursor": cursor
            ])
        } else {
            return try await convexClient.action("studySessions:fetchAllPaginated", with: [
                "numItems": Double(numItems)
            ])
        }
    }

    func listStudySessionsPaginated(goalId: String, cursor: String? = nil, numItems: Int = 10) async throws -> PaginatedStudySessions {
        if let cursor = cursor {
            return try await convexClient.action("studySessions:fetchByGoalPaginated", with: [
                "goalId": goalId,
                "numItems": Double(numItems),
                "cursor": cursor
            ])
        } else {
            return try await convexClient.action("studySessions:fetchByGoalPaginated", with: [
                "goalId": goalId,
                "numItems": Double(numItems)
            ])
        }
    }

    func listArchivedTodosPaginated(cursor: String? = nil, numItems: Int = 20) async throws -> PaginatedTodos {
        if let cursor = cursor {
            return try await convexClient.action("todos:fetchArchivedPaginated", with: [
                "numItems": Double(numItems),
                "cursor": cursor
            ])
        } else {
            return try await convexClient.action("todos:fetchArchivedPaginated", with: [
                "numItems": Double(numItems)
            ])
        }
    }

    func listCompletedTodosPaginated(cursor: String? = nil, numItems: Int = 20) async throws -> PaginatedTodos {
        if let cursor = cursor {
            return try await convexClient.action("todos:fetchCompletedPaginated", with: [
                "numItems": Double(numItems),
                "cursor": cursor
            ])
        } else {
            return try await convexClient.action("todos:fetchCompletedPaginated", with: [
                "numItems": Double(numItems)
            ])
        }
    }

    func listArchivedGoalsPaginated(cursor: String? = nil, numItems: Int = 20) async throws -> PaginatedGoals {
        if let cursor = cursor {
            return try await convexClient.action("goals:fetchArchivedPaginated", with: [
                "numItems": Double(numItems),
                "cursor": cursor
            ])
        } else {
            return try await convexClient.action("goals:fetchArchivedPaginated", with: [
                "numItems": Double(numItems)
            ])
        }
    }

    // MARK: - Account Management

    /// Deletes all user data from Convex (goals, sessions, todos)
    /// This should be called before deleting the Firebase user account
    func deleteAllUserData() async throws {
        let _: String? = try await convexClient.mutation("users:deleteAllData", with: [:])
    }

    // MARK: - Accountability Partners

    func listPartners() -> AnyPublisher<[Partner], Never> {
        convexClient.subscribe(to: "partners:list", yielding: [Partner].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func listSentInvites() -> AnyPublisher<[PartnerInvite], Never> {
        convexClient.subscribe(to: "partners:listSentInvites", yielding: [PartnerInvite].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func listReceivedInvites() -> AnyPublisher<[PartnerInvite], Never> {
        convexClient.subscribe(to: "partners:listReceivedInvites", yielding: [PartnerInvite].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getPendingInviteCount() -> AnyPublisher<Int, Never> {
        convexClient.subscribe(to: "partners:getPendingInviteCount", yielding: Int.self)
            .replaceError(with: 0)
            .eraseToAnyPublisher()
    }

    func sendPartnerInvite(email: String) async throws -> String {
        return try await convexClient.mutation("partners:sendInvite", with: [
            "email": email
        ])
    }

    func acceptPartnerInvite(inviteId: String) async throws {
        let _: String? = try await convexClient.mutation("partners:acceptInvite", with: [
            "inviteId": inviteId
        ])
    }

    func declinePartnerInvite(inviteId: String) async throws {
        let _: String? = try await convexClient.mutation("partners:declineInvite", with: [
            "inviteId": inviteId
        ])
    }

    func cancelPartnerInvite(inviteId: String) async throws {
        let _: String? = try await convexClient.mutation("partners:cancelInvite", with: [
            "inviteId": inviteId
        ])
    }

    func removePartner(partnerId: String) async throws {
        let _: String? = try await convexClient.mutation("partners:removePartner", with: [
            "partnerId": partnerId
        ])
    }

    // MARK: - Shared Videos

    func listSharedWithMe() -> AnyPublisher<[SharedVideo], Never> {
        convexClient.subscribe(to: "sharedVideos:listSharedWithMe", yielding: [SharedVideo].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getPartnerActivity(partnerId: String) -> AnyPublisher<[SharedVideo], Never> {
        convexClient.subscribe(to: "partners:getPartnerActivity", with: ["partnerId": partnerId], yielding: [SharedVideo].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func listMySharedVideos() -> AnyPublisher<[SharedVideo], Never> {
        convexClient.subscribe(to: "sharedVideos:listMyShared", yielding: [SharedVideo].self)
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func shareVideo(
        r2Key: String,
        thumbnailR2Key: String?,
        durationMinutes: Double,
        goalTitle: String?,
        todoTitle: String?,
        notes: String?,
        partnerIds: [String]
    ) async throws -> String {
        // Convert partnerIds array to JSON string since ConvexMobile doesn't support arrays directly
        let partnerIdsJSON = try JSONEncoder().encode(partnerIds)
        let partnerIdsString = String(data: partnerIdsJSON, encoding: .utf8) ?? "[]"

        // Build args based on what's provided
        if let thumb = thumbnailR2Key, let goal = goalTitle, let todo = todoTitle, let notes = notes, !notes.isEmpty {
            return try await convexClient.mutation("sharedVideos:shareVideo", with: [
                "r2Key": r2Key,
                "thumbnailR2Key": thumb,
                "durationMinutes": durationMinutes,
                "goalTitle": goal,
                "todoTitle": todo,
                "notes": notes,
                "partnerIdsJSON": partnerIdsString
            ])
        } else if let thumb = thumbnailR2Key, let goal = goalTitle {
            return try await convexClient.mutation("sharedVideos:shareVideo", with: [
                "r2Key": r2Key,
                "thumbnailR2Key": thumb,
                "durationMinutes": durationMinutes,
                "goalTitle": goal,
                "partnerIdsJSON": partnerIdsString
            ])
        } else if let thumb = thumbnailR2Key {
            return try await convexClient.mutation("sharedVideos:shareVideo", with: [
                "r2Key": r2Key,
                "thumbnailR2Key": thumb,
                "durationMinutes": durationMinutes,
                "partnerIdsJSON": partnerIdsString
            ])
        } else {
            return try await convexClient.mutation("sharedVideos:shareVideo", with: [
                "r2Key": r2Key,
                "durationMinutes": durationMinutes,
                "partnerIdsJSON": partnerIdsString
            ])
        }
    }

    func getSharedVideoUrl(videoId: String) async throws -> String {
        return try await convexClient.action("sharedVideos:getViewUrl", with: [
            "videoId": videoId
        ])
    }

    func getSharedVideoThumbnailUrl(videoId: String) async throws -> String? {
        return try await convexClient.action("sharedVideos:getThumbnailUrl", with: [
            "videoId": videoId
        ])
    }

    func deleteSharedVideo(videoId: String) async throws {
        let _: String? = try await convexClient.mutation("sharedVideos:remove", with: [
            "videoId": videoId
        ])
    }

    // MARK: - R2 Upload URLs

    struct R2UploadResponse: Decodable {
        let key: String
        let url: String
    }

    func generateUploadUrl() async throws -> R2UploadResponse {
        return try await convexClient.mutation("r2:generateUploadUrl", with: [:])
    }

    func syncR2Metadata(key: String) async throws {
        let _: String? = try await convexClient.mutation("r2:syncMetadata", with: [
            "key": key
        ])
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

// MARK: - Paginated Result

struct PaginatedStudySessions: Decodable {
    let page: [StudySession]
    let continueCursor: String?
    let isDone: Bool
}

struct PaginatedTodos: Decodable {
    let page: [TodoItem]
    let continueCursor: String?
    let isDone: Bool
}

struct PaginatedGoals: Decodable {
    let page: [Goal]
    let continueCursor: String?
    let isDone: Bool
}
