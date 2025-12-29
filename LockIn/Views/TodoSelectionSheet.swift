//
//  TodoSelectionSheet.swift
//  LockIn
//
//  Created by Claude on 27/12/25.
//

import SwiftUI

struct TodoSelectionSheet: View {
    @StateObject private var todoViewModel = TodoViewModel()
    @Binding var selectedTodoIds: Set<String>
    let onStart: () -> Void
    let onSkip: () -> Void

    private var incompleteTodos: [TodoItem] {
        todoViewModel.todos.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)

                Text("Select Tasks")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("What do you want to work on?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            // Todo list
            if todoViewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.accentColor)
                Spacer()
            } else if incompleteTodos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No pending todos")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(incompleteTodos) { todo in
                            TodoSelectionRow(
                                todo: todo,
                                isSelected: selectedTodoIds.contains(todo.id),
                                onToggle: {
                                    if selectedTodoIds.contains(todo.id) {
                                        selectedTodoIds.remove(todo.id)
                                    } else {
                                        selectedTodoIds.insert(todo.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                // Start recording button
                Button {
                    onStart()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill")
                        Text(selectedTodoIds.isEmpty ? "Start Without Tasks" : "Start Recording")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
                    .cornerRadius(14)
                }

                // Skip button
                if !incompleteTodos.isEmpty && selectedTodoIds.isEmpty {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip task selection")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct TodoSelectionRow: View {
    let todo: TodoItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                // Title
                Text(todo.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(UIColor.separator), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TodoSelectionSheet(
        selectedTodoIds: .constant(["1"]),
        onStart: {},
        onSkip: {}
    )
}
