//
//  ArchivedItemsView.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI
import Combine

struct ArchivedItemsView: View {
    @StateObject private var viewModel = ArchivedItemsViewModel()
    @State private var selectedTab = 0
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("", selection: $selectedTab) {
                Text("Goals").tag(0)
                Text("To-Dos").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                archivedGoalsContent
            } else {
                archivedTodosContent
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Archived")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { tabBarVisibility.hide() }
        .onDisappear { tabBarVisibility.show() }
    }

    // MARK: - Archived Goals

    var archivedGoalsContent: some View {
        Group {
            if viewModel.isLoadingGoals && viewModel.archivedGoals.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.archivedGoals.isEmpty {
                emptyState(title: "No Archived Goals", message: "Goals you archive will appear here")
            } else {
                List {
                    ForEach(viewModel.archivedGoals) { goal in
                        ArchivedGoalRow(goal: goal)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await viewModel.unarchiveGoal(goal)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.accentColor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteGoal(goal)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }

                    // Load more indicator
                    if viewModel.canLoadMoreGoals {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .onAppear {
                            Task { await viewModel.loadMoreGoals() }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }

    // MARK: - Archived Todos

    var archivedTodosContent: some View {
        Group {
            if viewModel.isLoadingTodos && viewModel.archivedTodos.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.archivedTodos.isEmpty {
                emptyState(title: "No Archived To-Dos", message: "To-dos you archive will appear here")
            } else {
                List {
                    ForEach(viewModel.archivedTodos) { todo in
                        ArchivedTodoRow(todo: todo)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await viewModel.unarchiveTodo(todo)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.accentColor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteTodo(todo)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }

                    // Load more indicator
                    if viewModel.canLoadMoreTodos {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .onAppear {
                            Task { await viewModel.loadMoreTodos() }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }

    func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Row Views

struct ArchivedGoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline.bold())

                Text(goal.completedHours.formattedProgress(of: goal.targetHours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(goal.progressPercentage))%")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}

struct ArchivedTodoRow: View {
    let todo: TodoItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.subheadline)
                    .strikethrough(todo.isCompleted)

                if let description = todo.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if todo.hasVideo {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class ArchivedItemsViewModel: ObservableObject {
    @Published var archivedGoals: [Goal] = []
    @Published var archivedTodos: [TodoItem] = []
    @Published var isLoadingGoals = false
    @Published var isLoadingTodos = false
    @Published var canLoadMoreGoals = true
    @Published var canLoadMoreTodos = true

    private var goalsCursor: String?
    private var todosCursor: String?
    private let convexService = ConvexService.shared

    init() {
        Task {
            await loadMoreGoals()
            await loadMoreTodos()
        }
    }

    func loadMoreGoals() async {
        guard !isLoadingGoals && canLoadMoreGoals else { return }

        isLoadingGoals = true
        defer { isLoadingGoals = false }

        do {
            let result = try await convexService.listArchivedGoalsPaginated(
                cursor: goalsCursor,
                numItems: 20
            )

            // Avoid duplicates
            for goal in result.page {
                if !archivedGoals.contains(where: { $0.id == goal.id }) {
                    archivedGoals.append(goal)
                }
            }

            goalsCursor = result.continueCursor
            canLoadMoreGoals = !result.isDone
        } catch {
            print("Failed to load archived goals: \(error)")
        }
    }

    func loadMoreTodos() async {
        guard !isLoadingTodos && canLoadMoreTodos else { return }

        isLoadingTodos = true
        defer { isLoadingTodos = false }

        do {
            let result = try await convexService.listArchivedTodosPaginated(
                cursor: todosCursor,
                numItems: 20
            )

            // Avoid duplicates
            for todo in result.page {
                if !archivedTodos.contains(where: { $0.id == todo.id }) {
                    archivedTodos.append(todo)
                }
            }

            todosCursor = result.continueCursor
            canLoadMoreTodos = !result.isDone
        } catch {
            print("Failed to load archived todos: \(error)")
        }
    }

    func refresh() async {
        goalsCursor = nil
        todosCursor = nil
        canLoadMoreGoals = true
        canLoadMoreTodos = true
        archivedGoals = []
        archivedTodos = []

        await loadMoreGoals()
        await loadMoreTodos()
    }

    func unarchiveGoal(_ goal: Goal) async {
        do {
            try await convexService.unarchiveGoal(id: goal.id)
            archivedGoals.removeAll { $0.id == goal.id }
        } catch {
            print("Failed to unarchive goal: \(error)")
        }
    }

    func unarchiveTodo(_ todo: TodoItem) async {
        do {
            try await convexService.unarchiveTodo(id: todo.id)
            archivedTodos.removeAll { $0.id == todo.id }
        } catch {
            print("Failed to unarchive todo: \(error)")
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await convexService.deleteGoal(id: goal.id)
            archivedGoals.removeAll { $0.id == goal.id }
        } catch {
            print("Failed to delete goal: \(error)")
        }
    }

    func deleteTodo(_ todo: TodoItem) async {
        do {
            try await convexService.deleteTodo(
                id: todo.id,
                localVideoPath: todo.localVideoPath,
                localThumbnailPath: todo.localThumbnailPath
            )
            archivedTodos.removeAll { $0.id == todo.id }
        } catch {
            print("Failed to delete todo: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ArchivedItemsView()
    }
}
