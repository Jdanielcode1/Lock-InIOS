//
//  SDTodoItem.swift
//  LockIn
//
//  SwiftData model for local caching of TodoItem data from Convex
//

import Foundation
import SwiftData

@Model
final class SDTodoItem {
    @Attribute(.unique) var convexId: String
    var title: String
    var todoDescription: String?
    var isCompleted: Bool
    var localVideoPath: String?
    var localThumbnailPath: String?
    var videoNotes: String?
    var speedSegmentsJSON: String?
    var createdAt: Double
    var lastSyncedAt: Date

    init(
        convexId: String,
        title: String,
        todoDescription: String?,
        isCompleted: Bool,
        localVideoPath: String?,
        localThumbnailPath: String?,
        videoNotes: String?,
        speedSegmentsJSON: String?,
        createdAt: Double
    ) {
        self.convexId = convexId
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.localVideoPath = localVideoPath
        self.localThumbnailPath = localThumbnailPath
        self.videoNotes = videoNotes
        self.speedSegmentsJSON = speedSegmentsJSON
        self.createdAt = createdAt
        self.lastSyncedAt = Date()
    }

    /// Initialize from Convex TodoItem model
    convenience init(from todo: TodoItem) {
        self.init(
            convexId: todo.id,
            title: todo.title,
            todoDescription: todo.description,
            isCompleted: todo.isCompleted,
            localVideoPath: todo.localVideoPath,
            localThumbnailPath: todo.localThumbnailPath,
            videoNotes: todo.videoNotes,
            speedSegmentsJSON: todo.speedSegmentsJSON,
            createdAt: todo.createdAt
        )
    }

    /// Update from Convex TodoItem model
    func update(from todo: TodoItem) {
        self.title = todo.title
        self.todoDescription = todo.description
        self.isCompleted = todo.isCompleted
        self.localVideoPath = todo.localVideoPath
        self.localThumbnailPath = todo.localThumbnailPath
        self.videoNotes = todo.videoNotes
        self.speedSegmentsJSON = todo.speedSegmentsJSON
        self.lastSyncedAt = Date()
    }

    /// Convert back to Convex TodoItem model
    func toTodoItem() -> TodoItem {
        TodoItem(
            _id: convexId,
            title: title,
            description: todoDescription,
            isCompleted: isCompleted,
            localVideoPath: localVideoPath,
            localThumbnailPath: localThumbnailPath,
            videoNotes: videoNotes,
            speedSegmentsJSON: speedSegmentsJSON,
            createdAt: createdAt
        )
    }
}
