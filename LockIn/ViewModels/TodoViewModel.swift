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
    private var todosSubscription: AnyCancellable?  // Separate subscription for data (can be cancelled on auth loss)
    private var goalTodosSubscription: AnyCancellable?
    private var isSubscribed = false  // Track subscription state to avoid duplicates
    private let convexService = ConvexService.shared

    init() {
        // Load cached data immediately for instant UI
        loadCachedData()
        monitorAuthAndSubscribe()
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

    /// Continuously monitor auth state and subscribe/unsubscribe accordingly
    /// This ensures we recover from auth token expiration
    private func monitorAuthAndSubscribe() {
        isLoading = true

        convexClient.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }

                switch state {
                case .authenticated:
                    // Only subscribe if not already subscribed (avoid duplicates)
                    if !self.isSubscribed {
                        print("🔄 TodoViewModel: Auth recovered, re-subscribing...")
                        self.subscribeToTodos()
                        self.subscribeToGoalTodos()
                    }
                case .unauthenticated:
                    // Cancel data subscription on auth loss (will re-subscribe on recovery)
                    self.cancelDataSubscriptions()
                case .loading:
                    // Keep current state while loading
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToTodos() {
        isSubscribed = true

        todosSubscription = convexService.listTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.todos = todos
                self?.isLoading = false

                // Update cache in background
                Task {
                    await DataCacheService.shared.save(todos, for: .todos)
                }
            }
    }

    private func subscribeToGoalTodos() {
        goalTodosSubscription = convexService.listAllGoalTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goalTodos in
                self?.goalTodos = goalTodos

                // Update cache in background
                Task {
                    await DataCacheService.shared.save(goalTodos, for: .goalTodos)
                }
            }
    }

    private func cancelDataSubscriptions() {
        todosSubscription?.cancel()
        todosSubscription = nil
        goalTodosSubscription?.cancel()
        goalTodosSubscription = nil
        isSubscribed = false
        // Don't clear data - keep showing cached data
        print("⚠️ TodoViewModel: Auth lost, subscriptions cancelled (keeping cached data)")
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

    /// Delete goal todo with undo support - archives first, then hard deletes after 4 seconds
    func deleteGoalTodoWithUndo(_ todo: GoalTodo) async {
        do {
            // 1. Archive immediately (soft delete - item disappears from list)
            try await convexService.archiveGoalTodo(id: todo.id)

            // 2. Show toast with undo option
            ToastManager.shared.showDeleted(
                "Task",
                undoAction: { [weak self] in
                    Task {
                        try? await self?.convexService.unarchiveGoalTodo(id: todo.id)
                    }
                },
                hardDeleteAction: { [weak self] in
                    Task {
                        try? await self?.convexService.deleteGoalTodo(id: todo.id)
                    }
                }
            )
        } catch {
            errorMessage = "Failed to delete task: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't delete task. Please try again."))
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

    /// Delete todo with undo support - archives first, then hard deletes after 4 seconds
    func deleteTodoWithUndo(_ todo: TodoItem) async {
        do {
            // 1. Archive immediately (soft delete - item disappears from list)
            try await convexService.archiveTodo(id: todo.id)

            // 2. Show toast with undo option
            ToastManager.shared.showDeleted(
                "To-do",
                undoAction: { [weak self] in
                    Task {
                        try? await self?.convexService.unarchiveTodo(id: todo.id)
                    }
                },
                hardDeleteAction: { [weak self] in
                    Task {
                        try? await self?.convexService.deleteTodo(
                            id: todo.id,
                            localVideoPath: todo.localVideoPath,
                            localThumbnailPath: todo.localThumbnailPath
                        )
                    }
                }
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
