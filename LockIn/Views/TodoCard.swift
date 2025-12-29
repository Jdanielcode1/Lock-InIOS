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
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(2)

                if let description = todo.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Video indicator
                if todo.hasVideo {
                    Label("Video attached", systemImage: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Arrow to record/view
            if !todo.hasVideo && !todo.isCompleted {
                Image(systemName: "video.badge.plus")
                    .foregroundStyle(.tertiary)
            }
        }
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
