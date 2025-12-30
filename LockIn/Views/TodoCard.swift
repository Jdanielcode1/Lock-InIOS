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
    var onRecord: (() -> Void)? = nil
    var onDetail: (() -> Void)? = nil

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

            // Content - tappable area for detail view
            Button {
                onDetail?()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .strikethrough(todo.isCompleted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let description = todo.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }

                    // Video indicator
                    if todo.hasVideo {
                        Label("Video attached", systemImage: "video.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Record/Play button on right side
            Button {
                onRecord?()
            } label: {
                if todo.hasVideo {
                    // Play button if video exists
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    // Record button if no video
                    Image(systemName: "video.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
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
            onRecord: {},
            onDetail: {}
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
            onRecord: {},
            onDetail: {}
        )
    }
    .padding()
}
