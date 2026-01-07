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
    @FocusState private var isTodoFieldFocused: Bool

    private var activeGoals: [Goal] {
        goalsViewModel.goals.filter { $0.status == .active }
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
                                startTodoRecording()
                            }
                            .disabled(isCreatingTodo)

                        if isCreatingTodo {
                            ProgressView()
                        } else {
                            Button {
                                startTodoRecording()
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

                // Goals Section
                Section {
                    if activeGoals.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No active goals")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(activeGoals) { goal in
                            GoalRow(goal: goal) {
                                startGoalRecording(goal: goal)
                            }
                        }
                    }
                } header: {
                    Text("Goal Session")
                } footer: {
                    if !activeGoals.isEmpty {
                        Text("Track time on a goal")
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
        }
    }

    private func startGoalRecording(goal: Goal) {
        let todos = availableTodosForGoal(goal)
        dismiss()
        // Use RecordingSessionManager - presented at RootView level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            recordingSession.startGoalSession(
                goalId: goal.id,
                goalTodoId: nil,
                availableTodos: todos
            )
        }
    }

    private func startTodoRecording() {
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
                    // Use RecordingSessionManager - presented at RootView level
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

// MARK: - Goal Row

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

#Preview {
    LockInStartView(
        goalsViewModel: GoalsViewModel(),
        todoViewModel: TodoViewModel()
    )
    .environmentObject(RecordingSessionManager.shared)
}
