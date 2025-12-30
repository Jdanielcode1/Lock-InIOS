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
    var onRecord: (() -> Void)? = nil

    @State private var thumbnail: UIImage?

    var body: some View {
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

            // Content - tappable for hours-based todos
            Button(action: onTap) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Record/Play button for simple todos
            if todo.todoType == .simple {
                Button {
                    onRecord?()
                } label: {
                    if todo.hasVideo {
                        // Video thumbnail with play overlay
                        ZStack {
                            if let thumbnail = thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 50, height: 38)
                            }

                            // Play icon overlay
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                    } else {
                        // Record button if no video
                        Image(systemName: "video.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Progress for hours-based todos + chevron
                HStack(spacing: 8) {
                    Text("\(Int(todo.progressPercentage))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(todo.isHoursCompleted ? .green : .secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: todo.localThumbnailPath) { _, _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let thumbnailURL = todo.thumbnailURL,
              FileManager.default.fileExists(atPath: thumbnailURL.path),
              let data = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: data) else {
            return
        }
        thumbnail = image
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
