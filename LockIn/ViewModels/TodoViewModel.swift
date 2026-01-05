//
//  TodoViewModel.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import Foundation
import Combine
import ConvexMobile

@MainActor
class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var goalTodos: [GoalTodo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    init() {
        // Load cached data immediately for instant UI
        loadCachedData()
        waitForAuthThenSubscribe()
    }

    /// Load cached todos for instant app launch
    private func loadCachedData() {
        Task {
            // Load todos
            if let cachedTodos: [TodoItem] = await DataCacheService.shared.load(.todos) {
                if self.todos.isEmpty {
                    self.todos = cachedTodos
                }
            }
            // Load goal todos
            if let cachedGoalTodos: [GoalTodo] = await DataCacheService.shared.load(.goalTodos) {
                if self.goalTodos.isEmpty {
                    self.goalTodos = cachedGoalTodos
                }
            }
        }
    }

    /// Wait for authenticated state before subscribing to avoid "Unauthenticated call" errors
    private func waitForAuthThenSubscribe() {
        isLoading = true

        convexClient.authState
            .compactMap { state -> Bool? in
                switch state {
                case .authenticated:
                    return true
                case .unauthenticated:
                    return nil // Keep waiting
                case .loading:
                    return nil // Keep waiting
                }
            }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.subscribeToTodos()
                self?.subscribeToGoalTodos()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTodos() {
        convexService.listTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.todos = todos
                self?.isLoading = false

                // Update cache in background
                Task {
                    await DataCacheService.shared.save(todos, for: .todos)
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToGoalTodos() {
        convexService.listAllGoalTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goalTodos in
                self?.goalTodos = goalTodos

                // Update cache in background
                Task {
                    await DataCacheService.shared.save(goalTodos, for: .goalTodos)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Goal Todo Actions

    func toggleGoalTodo(_ todo: GoalTodo) async {
        do {
            try await convexService.toggleGoalTodo(id: todo.id, isCompleted: !todo.isCompleted)
        } catch {
            errorMessage = "Failed to update todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't update todo. Please try again."))
        }
    }

    func deleteGoalTodo(_ todo: GoalTodo) async {
        do {
            try await convexService.deleteGoalTodo(id: todo.id)
        } catch {
            errorMessage = "Failed to delete todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't delete todo. Please try again."))
        }
    }

    func createTodo(title: String, description: String?) async {
        do {
            _ = try await convexService.createTodo(
                title: title,
                description: description
            )
        } catch {
            errorMessage = "Failed to create todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't create todo. Please try again."))
        }
    }

    func toggleTodo(_ todo: TodoItem) async {
        do {
            try await convexService.toggleTodo(id: todo.id, isCompleted: !todo.isCompleted)
        } catch {
            errorMessage = "Failed to update todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't update todo. Please try again."))
        }
    }

    func toggleTodoById(_ id: String, isCompleted: Bool) async {
        do {
            try await convexService.toggleTodo(id: id, isCompleted: isCompleted)
        } catch {
            errorMessage = "Failed to update todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't update todo. Please try again."))
        }
    }

    func attachVideo(to todo: TodoItem, videoPath: String, thumbnailPath: String?, videoNotes: String? = nil, speedSegmentsJSON: String? = nil) async {
        do {
            try await convexService.attachVideoToTodo(
                id: todo.id,
                localVideoPath: videoPath,
                localThumbnailPath: thumbnailPath,
                videoNotes: videoNotes,
                speedSegmentsJSON: speedSegmentsJSON
            )
        } catch {
            errorMessage = "Failed to attach video: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.videoError("Couldn't save the video. Please try again."))
        }
    }

    func attachVideoToMultiple(todoIds: [String], videoPath: String, thumbnailPath: String?, videoNotes: String? = nil, speedSegmentsJSON: String? = nil) async {
        do {
            try await convexService.attachVideoToMultipleTodos(
                ids: todoIds,
                localVideoPath: videoPath,
                localThumbnailPath: thumbnailPath,
                videoNotes: videoNotes,
                speedSegmentsJSON: speedSegmentsJSON
            )
        } catch {
            errorMessage = "Failed to attach video: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.videoError("Couldn't save the video. Please try again."))
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
            ErrorAlertManager.shared.show(.saveFailed("Couldn't delete todo. Please try again."))
        }
    }

    func archiveTodo(_ todo: TodoItem) async {
        do {
            try await convexService.archiveTodo(id: todo.id)
        } catch {
            errorMessage = "Failed to archive todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't archive todo. Please try again."))
        }
    }

    func createGoalTodo(
        goalId: String,
        title: String,
        description: String?,
        todoType: GoalTodoType = .simple,
        estimatedHours: Double? = nil,
        frequency: TodoFrequency = .none
    ) async {
        do {
            _ = try await convexService.createGoalTodo(
                goalId: goalId,
                title: title,
                description: description,
                todoType: todoType,
                estimatedHours: estimatedHours,
                frequency: frequency
            )
        } catch {
            errorMessage = "Failed to create goal todo: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't create todo. Please try again."))
        }
    }
}
