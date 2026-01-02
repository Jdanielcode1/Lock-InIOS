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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Record/Play button on right side
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
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: todo.localThumbnailPath) { _, _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let thumbnailURL = todo.thumbnailURL else { return }
        Task {
            if let image = await ThumbnailCache.shared.thumbnail(for: thumbnailURL) {
                await MainActor.run { thumbnail = image }
            }
        }
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
