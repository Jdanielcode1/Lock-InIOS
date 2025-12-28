//
//  TodoViewModel.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import Foundation
import Combine

@MainActor
class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    init() {
        subscribeToTodos()
    }

    private func subscribeToTodos() {
        isLoading = true

        convexService.listTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.todos = todos
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func createTodo(title: String, description: String?) async {
        do {
            _ = try await convexService.createTodo(
                title: title,
                description: description
            )
        } catch {
            errorMessage = "Failed to create todo: \(error.localizedDescription)"
        }
    }

    func toggleTodo(_ todo: TodoItem) async {
        do {
            try await convexService.toggleTodo(id: todo.id, isCompleted: !todo.isCompleted)
        } catch {
            errorMessage = "Failed to update todo: \(error.localizedDescription)"
        }
    }

    func toggleTodoById(_ id: String, isCompleted: Bool) async {
        do {
            try await convexService.toggleTodo(id: id, isCompleted: isCompleted)
        } catch {
            errorMessage = "Failed to update todo: \(error.localizedDescription)"
        }
    }

    func attachVideo(to todo: TodoItem, videoPath: String, thumbnailPath: String?) async {
        do {
            try await convexService.attachVideoToTodo(
                id: todo.id,
                localVideoPath: videoPath,
                localThumbnailPath: thumbnailPath
            )
        } catch {
            errorMessage = "Failed to attach video: \(error.localizedDescription)"
        }
    }

    func deleteTodo(_ todo: TodoItem) async {
        do {
            try await convexService.deleteTodo(
                id: todo.id,
                localVideoPath: todo.localVideoPath,
                localThumbnailPath: todo.localThumbnailPath
            )
        } catch {
            errorMessage = "Failed to delete todo: \(error.localizedDescription)"
        }
    }

    func archiveTodo(_ todo: TodoItem) async {
        do {
            try await convexService.archiveTodo(id: todo.id)
        } catch {
            errorMessage = "Failed to archive todo: \(error.localizedDescription)"
        }
    }
}
