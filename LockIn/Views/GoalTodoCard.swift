//
//  GoalTodoCard.swift
//  LockIn
//
//  Created by Claude on 29/12/25.
//

import SwiftUI

struct GoalTodoCard: View {
    let todo: GoalTodo
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox for simple todos
                if todo.todoType == .simple {
                    Button(action: onToggle) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(todo.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .strikethrough(todo.isCompleted && todo.todoType == .simple)

                        // Recurring badge
                        if todo.isRecurring {
                            Image(systemName: todo.frequency.icon)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    if let desc = todo.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Hours info for hours-based todos
                    if todo.todoType == .hours {
                        HStack(spacing: 12) {
                            Label(
                                (todo.completedHours ?? 0).formattedProgressCompact(of: todo.estimatedHours ?? 0),
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if todo.isHoursCompleted {
                                Label("Complete", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // Video indicator
                    if todo.hasVideo {
                        Label("Video attached", systemImage: "video.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Progress for hours-based todos
                if todo.todoType == .hours {
                    Text("\(Int(todo.progressPercentage))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(todo.isHoursCompleted ? .green : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        // Simple todo - incomplete
        GoalTodoCard(
            todo: GoalTodo(
                _id: "1",
                goalId: "goal1",
                title: "Review lecture notes",
                description: "Go through chapter 5 notes",
                todoType: .simple,
                estimatedHours: nil,
                completedHours: nil,
                isCompleted: false,
                frequency: .daily,
                lastResetAt: nil,
                localVideoPath: nil,
                localThumbnailPath: nil,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onToggle: {},
            onTap: {}
        )
        Divider().padding(.leading, 16)

        // Simple todo - completed
        GoalTodoCard(
            todo: GoalTodo(
                _id: "2",
                goalId: "goal1",
                title: "Practice problems",
                description: "Complete exercises 1-10",
                todoType: .simple,
                estimatedHours: nil,
                completedHours: nil,
                isCompleted: true,
                frequency: .none,
                lastResetAt: nil,
                localVideoPath: nil,
                localThumbnailPath: nil,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onToggle: {},
            onTap: {}
        )
        Divider().padding(.leading, 16)

        // Hours-based todo
        GoalTodoCard(
            todo: GoalTodo(
                _id: "3",
                goalId: "goal1",
                title: "Build project",
                description: "Complete the main feature",
                todoType: .hours,
                estimatedHours: 10,
                completedHours: 3.5,
                isCompleted: false,
                frequency: .weekly,
                lastResetAt: nil,
                localVideoPath: nil,
                localThumbnailPath: nil,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onToggle: {},
            onTap: {}
        )
    }
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
