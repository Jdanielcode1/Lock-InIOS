//
//  SubtaskCard.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct SubtaskCard: View {
    let subtask: Subtask

    var body: some View {
        HStack(spacing: 12) {
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(subtask.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                if !subtask.description.isEmpty {
                    Text(subtask.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Hours info
                HStack(spacing: 12) {
                    Label("\(String(format: "%.1f", subtask.completedHours))/\(String(format: "%.1f", subtask.estimatedHours)) hrs", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if subtask.isCompleted {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // Progress percentage
            Text("\(Int(subtask.progressPercentage))%")
                .font(.subheadline.bold())
                .foregroundStyle(subtask.isCompleted ? .green : .secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}

#Preview {
    VStack(spacing: 0) {
        SubtaskCard(subtask: Subtask(
            _id: "1",
            goalId: "goal1",
            title: "Learn SwiftUI Basics",
            description: "Understand views, modifiers, and state management",
            estimatedHours: 10,
            completedHours: 3.5,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
        Divider().padding(.leading, 16)
        SubtaskCard(subtask: Subtask(
            _id: "2",
            goalId: "goal1",
            title: "Build First App",
            description: "Create a simple todo list application",
            estimatedHours: 15,
            completedHours: 15,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
    }
    .background(Color(UIColor.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
