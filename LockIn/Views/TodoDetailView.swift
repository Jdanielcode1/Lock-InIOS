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

    @State private var title: String
    @State private var description: String
    @State private var isCompleted: Bool
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    @State private var hasChanges = false
    @State private var showingRecorder = false
    @State private var showingVideoPlayer = false
    @FocusState private var titleFocused: Bool

    private let convexService = ConvexService.shared
    @StateObject private var todoViewModel = TodoViewModel()

    // Reactive todo from subscription
    private var todo: TodoItem {
        todoViewModel.todos.first(where: { $0.id == initialTodo.id }) ?? initialTodo
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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: todo.createdDate)
    }

    var body: some View {
        NavigationView {
            List {
                // Status Section
                Section {
                    HStack(spacing: 16) {
                        // Completion toggle
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isCompleted.toggle()
                                hasChanges = true
                            }

                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 28))
                                .foregroundStyle(isCompleted ? .green : Color(UIColor.tertiaryLabel))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isCompleted ? "Completed" : "In Progress")
                                .font(.headline)
                                .foregroundStyle(isCompleted ? .green : .primary)

                            Text("Tap to toggle status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Status")
                }

                // Title Section
                Section {
                    TextField("Todo title", text: $title)
                        .font(.body)
                        .focused($titleFocused)
                        .onChange(of: title) { _, _ in
                            hasChanges = true
                        }
                } header: {
                    Text("Title")
                } footer: {
                    if !isValid && !title.isEmpty {
                        Text("Title cannot be empty")
                            .foregroundStyle(.red)
                    }
                }

                // Description Section
                Section {
                    TextField("Add notes or details...", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: description) { _, _ in
                            hasChanges = true
                        }
                } header: {
                    Text("Description")
                } footer: {
                    Text("Optional")
                }

                // Video/Recording Section
                Section {
                    if todo.hasVideo {
                        // Play video button
                        Button {
                            showingVideoPlayer = true
                        } label: {
                            HStack(spacing: 12) {
                                // Thumbnail
                                if let thumbnailURL = todo.thumbnailURL,
                                   let data = try? Data(contentsOf: thumbnailURL),
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 45)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: 60, height: 45)
                                        .overlay {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Watch Recording")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)

                                    Text("Tap to play video proof")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        // Record button
                        Button {
                            showingRecorder = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 60, height: 45)

                                    Image(systemName: "video.badge.plus")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Record Video")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)

                                    Text("Add proof for this todo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Recording")
                } footer: {
                    if todo.hasVideo {
                        Text("Video proof attached")
                    } else {
                        Text("Record a video to prove completion")
                    }
                }

                // Info Section
                Section {
                    HStack {
                        Label("Created", systemImage: "calendar")
                        Spacer()
                        Text(formattedDate)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("ID", systemImage: "number")
                        Spacer()
                        Text(String(todo.id.prefix(8)) + "...")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Info")
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Label("Delete Todo", systemImage: "trash.fill")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("This action cannot be undone.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValid || isSaving || !hasChanges)
                }
            }
            .alert("Delete Todo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteTodo()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this todo? This action cannot be undone.")
            }
            .fullScreenCover(isPresented: $showingRecorder) {
                TodoRecorderView(todo: todo, viewModel: todoViewModel)
            }
            .fullScreenCover(isPresented: $showingVideoPlayer) {
                if let videoURL = todo.videoURL {
                    TodoVideoPlayerView(videoURL: videoURL, todo: todo)
                }
            }
            .onChange(of: todo.isCompleted) { _, newValue in
                // Sync completion status when todo updates from backend (e.g., after recording)
                if !hasChanges {
                    isCompleted = newValue
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }

    private func saveChanges() async {
        isSaving = true

        do {
            // Update title and description
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

            try await convexService.updateTodo(
                id: todo.id,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )

            // Update completion status if changed
            if isCompleted != todo.isCompleted {
                try await convexService.toggleTodo(id: todo.id, isCompleted: isCompleted)
            }

            dismiss()
        } catch {
            print("Failed to save todo: \(error)")
            isSaving = false
        }
    }

    private func deleteTodo() async {
        do {
            try await convexService.deleteTodo(
                id: todo.id,
                localVideoPath: todo.localVideoPath,
                localThumbnailPath: todo.localThumbnailPath
            )
            dismiss()
        } catch {
            print("Failed to delete todo: \(error)")
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
        createdAt: Date().timeIntervalSince1970 * 1000
    ))
}
