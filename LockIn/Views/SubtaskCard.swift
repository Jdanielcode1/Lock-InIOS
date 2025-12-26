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
        VStack(alignment: .leading, spacing: 12) {
            // Title and hours
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtask.title)
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(subtask.description)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Progress percentage
                ZStack {
                    Circle()
                        .stroke(AppTheme.borderLight, lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: subtask.progressPercentage / 100)
                        .stroke(
                            AppTheme.progressGradient(for: subtask.progressPercentage),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(AppTheme.smoothAnimation, value: subtask.progressPercentage)

                    Text("\(Int(subtask.progressPercentage))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(String(format: "%.1f", subtask.completedHours))/\(String(format: "%.1f", subtask.estimatedHours)) hrs")
                            .font(AppTheme.captionFont)
                    }
                    .foregroundColor(AppTheme.textSecondary)

                    Spacer()

                    if subtask.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Complete")
                                .font(AppTheme.captionFont)
                        }
                        .foregroundStyle(AppTheme.successGradient)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                            Text("\(String(format: "%.1f", subtask.hoursRemaining)) hrs left")
                                .font(AppTheme.captionFont)
                        }
                        .foregroundColor(AppTheme.warningAmber)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.borderLight)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.progressGradient(for: subtask.progressPercentage))
                            .frame(width: geometry.size.width * (subtask.progressPercentage / 100), height: 8)
                            .animation(AppTheme.smoothAnimation, value: subtask.progressPercentage)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .playfulCard()
    }
}

#Preview {
    VStack(spacing: 16) {
        SubtaskCard(subtask: Subtask(
            _id: "1",
            goalId: "goal1",
            title: "Learn SwiftUI Basics",
            description: "Understand views, modifiers, and state management",
            estimatedHours: 10,
            completedHours: 3.5,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))

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
    .padding()
    .background(AppTheme.background)
}
