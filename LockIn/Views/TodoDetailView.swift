//
//  TodoDetailView.swift
//  LockIn
//
//  Created by Claude on 30/12/25.
//

import SwiftUI

struct TodoDetailView: View {
    let initialTodo: TodoItem
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var videoPlayerSession: VideoPlayerSessionManager
    @EnvironmentObject private var recordingSession: RecordingSessionManager

    @State private var title: String
    @State private var description: String
    @State private var isCompleted: Bool
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    @State private var thumbnail: UIImage?
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    private let convexService = ConvexService.shared
    @StateObject private var todoViewModel = TodoViewModel()

    private var todo: TodoItem {
        todoViewModel.todos.first(where: { $0.id == initialTodo.id }) ?? initialTodo
    }

    // Detect if todo was deleted (no longer in the subscription list)
    private var isTodoDeleted: Bool {
        !todoViewModel.isLoading && !todoViewModel.todos.isEmpty && todoViewModel.todos.first(where: { $0.id == initialTodo.id }) == nil
    }

    init(todo: TodoItem) {
        self.initialTodo = todo
        _title = State(initialValue: todo.title)
        _description = State(initialValue: todo.description ?? "")
        _isCompleted = State(initialValue: todo.isCompleted)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Title & Status
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            // Completion toggle
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isCompleted.toggle()
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task { await saveChanges() }
                            } label: {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(isCompleted ? Color.green : Color(.tertiaryLabel))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)

                            // Title field
                            TextField("What needs to be done?", text: $title, axis: .vertical)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isCompleted ? .secondary : .primary)
                                .strikethrough(isCompleted, color: .secondary)
                                .focused($titleFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    titleFocused = false
                                    Task { await saveChanges() }
                                }
                        }

                        // Description
                        TextField("Add notes...", text: $description, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(1...8)
                            .focused($descriptionFocused)
                            .padding(.leading, 40)
                            .onSubmit {
                                descriptionFocused = false
                                Task { await saveChanges() }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                    // MARK: - Video Section
                    VStack(spacing: 0) {
                        if todo.hasVideo {
                            // Video exists - show playback card
                            Button {
                                if let videoURL = todo.videoURL {
                                    videoPlayerSession.playTodoVideo(todo: todo, videoURL: videoURL) {
                                        recordingSession.startTodoRecording(todo: todo)
                                    }
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    // Thumbnail
                                    ZStack {
                                        if let thumbnail = thumbnail {
                                            Image(uiImage: thumbnail)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 72, height: 54)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 72, height: 54)
                                        }

                                        // Play icon
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .offset(x: 1)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Recording")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 11))
                                            Text("Verified")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundStyle(.green)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        } else {
                            // No video - show record button
                            Button {
                                recordingSession.startTodoRecording(todo: todo)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.accentColor.opacity(0.12))
                                            .frame(width: 72, height: 54)

                                        Image(systemName: "video.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(Color.accentColor)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Record Video")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        Text("Prove your work")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 40)

                    // MARK: - Delete
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Text("Delete")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await saveChanges()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Delete Todo?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteTodo() }
                }
            } message: {
                Text("You can undo this for a few seconds after deleting.")
            }
            .onChange(of: todo.isCompleted) { _, newValue in
                isCompleted = newValue
            }
            .onAppear {
                loadThumbnail()
            }
            .onChange(of: todo.localThumbnailPath) { _, _ in
                loadThumbnail()
            }
            .onChange(of: isTodoDeleted) { _, deleted in
                if deleted {
                    // Todo was deleted (e.g., from another device or via sync)
                    ToastManager.shared.showDeleted("To-do")
                    dismiss()
                }
            }
        }
    }

    private func loadThumbnail() {
        guard let thumbnailURL = todo.thumbnailURL else {
            thumbnail = nil
            return
        }
        Task {
            if let image = await ThumbnailCache.shared.thumbnail(for: thumbnailURL) {
                await MainActor.run { thumbnail = image }
            } else {
                await MainActor.run { thumbnail = nil }
            }
        }
    }

    private func saveChanges() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        do {
            try await convexService.updateTodo(
                id: todo.id,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )

            if isCompleted != todo.isCompleted {
                try await convexService.toggleTodo(id: todo.id, isCompleted: isCompleted)
            }
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func deleteTodo() async {
        let todoToDelete = todo
        do {
            // Archive first (soft delete - item disappears from list)
            try await convexService.archiveTodo(id: todoToDelete.id)
            dismiss()

            // Show toast with undo, hard delete after 4 seconds
            ToastManager.shared.showDeleted(
                "To-do",
                undoAction: {
                    Task { try? await convexService.unarchiveTodo(id: todoToDelete.id) }
                },
                hardDeleteAction: {
                    Task {
                        try? await convexService.deleteTodo(
                            id: todoToDelete.id,
                            localVideoPath: todoToDelete.localVideoPath,
                            localThumbnailPath: todoToDelete.localThumbnailPath
                        )
                    }
                }
            )
        } catch {
            print("Failed to delete: \(error)")
        }
    }
}

#Preview {
    TodoDetailView(todo: TodoItem(
        _id: "123456789",
        title: "Review Swift documentation",
        description: "Go through the new Swift 5.9 features and take notes",
        isCompleted: false,
        localVideoPath: nil,
        localThumbnailPath: nil,
        videoNotes: nil,
        createdAt: Date().timeIntervalSince1970 * 1000
    ))
}
