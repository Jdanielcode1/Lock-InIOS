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
    }

    // MARK: - Archived Goals

    var archivedGoalsContent: some View {
        Group {
            if viewModel.archivedGoals.isEmpty {
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
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Archived Todos

    var archivedTodosContent: some View {
        Group {
            if viewModel.archivedTodos.isEmpty {
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
                }
                .listStyle(.insetGrouped)
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

                Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours)) hours")
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

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    init() {
        subscribeToArchivedItems()
    }

    private func subscribeToArchivedItems() {
        convexService.listArchivedGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.archivedGoals = goals
            }
            .store(in: &cancellables)

        convexService.listArchivedTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.archivedTodos = todos
            }
            .store(in: &cancellables)
    }

    func unarchiveGoal(_ goal: Goal) async {
        do {
            try await convexService.unarchiveGoal(id: goal.id)
        } catch {
            print("Failed to unarchive goal: \(error)")
        }
    }

    func unarchiveTodo(_ todo: TodoItem) async {
        do {
            try await convexService.unarchiveTodo(id: todo.id)
        } catch {
            print("Failed to unarchive todo: \(error)")
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await convexService.deleteGoal(id: goal.id)
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
