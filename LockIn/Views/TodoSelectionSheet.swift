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
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .padding(.top, 24)

                Text("Select Tasks")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("What do you want to work on?")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.bottom, 20)

            // Todo list
            if todoViewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(AppTheme.actionBlue)
                Spacer()
            } else if incompleteTodos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("No pending todos")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
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
                            .font(.system(size: 16, weight: .semibold))
                        Text(selectedTodoIds.isEmpty ? "Start Without Tasks" : "Start Recording")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundColor(.white)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(14)
                }

                // Skip button
                if !incompleteTodos.isEmpty && selectedTodoIds.isEmpty {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip task selection")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .padding(.top, 16)
        }
        .background(Color.white)
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
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.actionBlue : AppTheme.textSecondary)

                // Title
                Text(todo.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? AppTheme.actionBlue.opacity(0.1) : Color.gray.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.actionBlue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
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
