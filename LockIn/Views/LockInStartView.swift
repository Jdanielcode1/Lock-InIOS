//
//  LockInStartView.swift
//  LockIn
//
//  Created by Claude on 07/01/26.
//

import SwiftUI

struct LockInStartView: View {
    @ObservedObject var goalsViewModel: GoalsViewModel
    @ObservedObject var todoViewModel: TodoViewModel

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var recordingSession: RecordingSessionManager

    @State private var todoTitle = ""
    @State private var isCreatingTodo = false
    @State private var showingCreateGoal = false
    @FocusState private var isTodoFieldFocused: Bool

    private var activeGoals: [Goal] {
        goalsViewModel.goals.filter { $0.status == .active }
    }

    private var standaloneTodos: [TodoItem] {
        todoViewModel.todos.filter { !$0.isCompleted }
    }

    private func availableTodosForGoal(_ goal: Goal) -> [GoalTodo] {
        todoViewModel.goalTodos.filter { $0.goalId == goal.id && !$0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick To-Do Section
                Section {
                    HStack(spacing: 12) {
                        TextField("Quick task...", text: $todoTitle)
                            .focused($isTodoFieldFocused)
                            .submitLabel(.go)
                            .onSubmit {
                                startNewTodoRecording()
                            }
                            .disabled(isCreatingTodo)

                        if isCreatingTodo {
                            ProgressView()
                        } else {
                            Button {
                                startNewTodoRecording()
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(todoTitle.isEmpty ? Color.secondary : Color.accentColor)
                            }
                            .disabled(todoTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                } header: {
                    Text("Quick To-Do")
                } footer: {
                    Text("Type a task and record it")
                }

                // Standalone Todos Section
                if !standaloneTodos.isEmpty {
                    Section {
                        ForEach(standaloneTodos) { todo in
                            TodoRow(todo: todo) {
                                startExistingTodoRecording(todo: todo)
                            }
                        }
                    } header: {
                        Text("Your Todos")
                    } footer: {
                        Text("Tap to start recording")
                    }
                }

                // Goals Section with expandable todos
                Section {
                    if activeGoals.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No active goals")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button {
                                showingCreateGoal = true
                            } label: {
                                Text("Create Goal")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.accentGreen)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(activeGoals) { goal in
                            let goalTodos = availableTodosForGoal(goal)

                            if goalTodos.isEmpty {
                                // No todos - just show the goal row
                                GoalRow(goal: goal) {
                                    startGoalRecording(goal: goal)
                                }
                            } else {
                                // Has todos - show expandable section
                                DisclosureGroup {
                                    ForEach(goalTodos) { goalTodo in
                                        LockInGoalTodoRow(goalTodo: goalTodo) {
                                            startGoalTodoRecording(goalTodo: goalTodo, goal: goal)
                                        }
                                    }
                                } label: {
                                    GoalRowContent(goal: goal, todoCount: goalTodos.count) {
                                        startGoalRecording(goal: goal)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Goal Session")
                } footer: {
                    if !activeGoals.isEmpty {
                        Text("Tap goal to start, or expand to pick a todo")
                    }
                }
            }
            .navigationTitle("Lock In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                CreateGoalView(viewModel: goalsViewModel)
            }
        }
    }

    // MARK: - Recording Actions

    private func startGoalRecording(goal: Goal) {
        let todos = availableTodosForGoal(goal)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            recordingSession.startGoalSession(
                goalId: goal.id,
                goalTodoId: nil,
                availableTodos: todos
            )
        }
    }

    private func startGoalTodoRecording(goalTodo: GoalTodo, goal: Goal) {
        let todos = availableTodosForGoal(goal)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            recordingSession.startGoalSession(
                goalId: goal.id,
                goalTodoId: goalTodo.id,
                availableTodos: todos
            )
        }
    }

    private func startExistingTodoRecording(todo: TodoItem) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            recordingSession.startTodoRecording(todo: todo)
        }
    }

    private func startNewTodoRecording() {
        let title = todoTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        isCreatingTodo = true

        Task {
            // Create the todo first
            await todoViewModel.createTodo(title: title, description: nil)

            // Wait for subscription to update
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Find the newly created todo
            if let newTodo = todoViewModel.todos.first(where: { $0.title == title }) {
                await MainActor.run {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        recordingSession.startTodoRecording(todo: newTodo)
                    }
                }
            } else {
                await MainActor.run {
                    isCreatingTodo = false
                }
            }
        }
    }
}

// MARK: - Standalone Todo Row

private struct TodoRow: View {
    let todo: TodoItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(todo.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Goal Row (non-expandable)

private struct GoalRow: View {
    let goal: Goal
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: goal.progressPercentage / 100)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("\(Int(goal.completedHours))h / \(Int(goal.targetHours))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Goal Row Content (for expandable)

private struct GoalRowContent: View {
    let goal: Goal
    let todoCount: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: goal.progressPercentage / 100)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text("\(Int(goal.completedHours))h / \(Int(goal.targetHours))h")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(todoCount) todo\(todoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal Todo Row (for Lock In sheet)

private struct LockInGoalTodoRow: View {
    let goalTodo: GoalTodo
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(goalTodo.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.leading, 8)
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    LockInStartView(
        goalsViewModel: GoalsViewModel(),
        todoViewModel: TodoViewModel()
    )
    .environmentObject(RecordingSessionManager.shared)
}
