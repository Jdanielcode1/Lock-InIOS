//
//  TodoCard.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI

struct TodoCard: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(todo.isCompleted ? AppTheme.successGreen : AppTheme.textSecondary)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(AppTheme.headlineFont)
                    .foregroundColor(todo.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(2)

                if let description = todo.description, !description.isEmpty {
                    Text(description)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                // Video thumbnail if attached
                if todo.hasVideo {
                    HStack(spacing: 8) {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.actionBlue.opacity(0.2))
                                .frame(width: 60, height: 40)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.actionBlue)
                                )
                        }

                        Text("Video attached")
                            .font(.caption2)
                            .foregroundColor(AppTheme.actionBlue)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Arrow to record/view
            if !todo.hasVideo {
                Image(systemName: "video.badge.plus")
                    .font(.title3)
                    .foregroundColor(AppTheme.actionBlue.opacity(0.6))
            }
        }
        .padding()
        .background(todo.isCompleted ? AppTheme.successGreen.opacity(0.05) : AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(todo.isCompleted ? AppTheme.successGreen.opacity(0.2) : AppTheme.borderLight, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
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
    VStack(spacing: 16) {
        TodoCard(
            todo: TodoItem(
                _id: "1",
                title: "Complete Swift tutorial",
                description: "Watch the advanced SwiftUI videos",
                isCompleted: false,
                localVideoPath: nil,
                localThumbnailPath: nil,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onToggle: {},
            onTap: {}
        )

        TodoCard(
            todo: TodoItem(
                _id: "2",
                title: "Review code changes",
                description: nil,
                isCompleted: true,
                localVideoPath: "video.mov",
                localThumbnailPath: nil,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onToggle: {},
            onTap: {}
        )
    }
    .padding()
}
