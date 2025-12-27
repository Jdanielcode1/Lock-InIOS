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
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    Text("Goals").tag(0)
                    Text("To-Dos").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)

                if selectedTab == 0 {
                    archivedGoalsContent
                } else {
                    archivedTodosContent
                }
            }
        }
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
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await viewModel.unarchiveGoal(goal)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(AppTheme.actionBlue)
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await viewModel.unarchiveTodo(todo)
                                    }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(AppTheme.actionBlue)
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours)) hours")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(Int(goal.progressPercentage))%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

struct ArchivedTodoRow: View {
    let todo: TodoItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(todo.isCompleted ? AppTheme.successGreen : AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .strikethrough(todo.isCompleted)

                if let description = todo.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if todo.hasVideo {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.actionBlue)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
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
