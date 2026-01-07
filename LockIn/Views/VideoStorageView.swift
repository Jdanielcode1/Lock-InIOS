//
//  VideoStorageView.swift
//  LockIn
//
//  Created by Claude on 06/01/26.
//

import SwiftUI
import Combine

// Unified video item for display
struct VideoItem: Identifiable {
    enum VideoType {
        case studySession(StudySession)
        case goalTodo(GoalTodo)
    }

    let id: String
    let type: VideoType
    let localVideoPath: String
    let localThumbnailPath: String?
    let goalTitle: String?
    let todoTitle: String?
    let durationMinutes: Double?
    let createdAt: Date
    let fileSize: Int64

    var thumbnailURL: URL? {
        guard let path = localThumbnailPath else { return nil }
        return LocalStorageService.shared.getFullURL(for: path)
    }

    var videoURL: URL? {
        LocalStorageService.shared.getFullURL(for: localVideoPath)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedDuration: String? {
        guard let minutes = durationMinutes, minutes > 0 else { return nil }
        if minutes < 1 {
            return "\(Int(minutes * 60))s"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes / 60)
            let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    var displayTitle: String {
        switch type {
        case .studySession:
            return "Session"
        case .goalTodo(let todo):
            return todo.title
        }
    }

    var subtitle: String {
        goalTitle ?? "Unknown Goal"
    }
}

struct VideoStorageView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var videos: [VideoItem] = []
    @State private var isLoading = true
    @State private var selectedIds: Set<String> = []
    @State private var isEditMode = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var totalSize: Int64 = 0

    private var cancellables = Set<AnyCancellable>()
    @State private var studySessions: [StudySession] = []
    @State private var goalTodos: [GoalTodo] = []
    @State private var goals: [Goal] = []

    var body: some View {
        VStack(spacing: 0) {
            // Storage summary header
            if !videos.isEmpty {
                HStack {
                    Text("\(formattedTotalSize) • \(videos.count) video\(videos.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isEditMode && !selectedIds.isEmpty {
                        Text("\(selectedIds.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
            }

            if isLoading {
                Spacer()
                ProgressView("Loading videos...")
                Spacer()
            } else if videos.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No Videos")
                        .font(.title3.bold())
                    Text("Videos from your recording sessions will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(videos) { video in
                        VideoRow(
                            video: video,
                            isSelected: selectedIds.contains(video.id),
                            isEditMode: isEditMode
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(video.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Manage Videos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditMode {
                    Button("Cancel") {
                        withAnimation {
                            isEditMode = false
                            selectedIds.removeAll()
                        }
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if !videos.isEmpty {
                    if isEditMode {
                        Button(selectedIds.count == videos.count ? "Deselect All" : "Select All") {
                            if selectedIds.count == videos.count {
                                selectedIds.removeAll()
                            } else {
                                selectedIds = Set(videos.map { $0.id })
                            }
                        }
                    } else {
                        Button("Edit") {
                            withAnimation {
                                isEditMode = true
                            }
                        }
                    }
                }
            }

            ToolbarItem(placement: .bottomBar) {
                if isEditMode && !selectedIds.isEmpty {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Delete \(selectedIds.count) Video\(selectedIds.count == 1 ? "" : "s")")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)
                }
            }
        }
        .onAppear {
            loadVideos()
        }
        .alert("Delete Videos?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedVideos()
            }
        } message: {
            Text("This will permanently delete \(selectedIds.count) video\(selectedIds.count == 1 ? "" : "s"). This action cannot be undone.")
        }
    }

    private var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func loadVideos() {
        isLoading = true

        // Load goals first for title lookup
        ConvexService.shared.listGoals()
            .combineLatest(
                ConvexService.shared.listAllStudySessions(),
                ConvexService.shared.listAllGoalTodos()
            )
            .receive(on: DispatchQueue.main)
            .sink { [self] goalsData, sessions, todos in
                self.goals = goalsData
                self.studySessions = sessions
                self.goalTodos = todos.filter { $0.localVideoPath != nil }

                self.buildVideoItems()
                self.isLoading = false
            }
            .store(in: &VideoStorageDataManager.shared.cancellables)
    }

    private func buildVideoItems() {
        var items: [VideoItem] = []
        var total: Int64 = 0

        // Create goal lookup
        let goalLookup = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.title) })

        // Add study sessions
        for session in studySessions {
            let fileSize = getFileSize(for: session.localVideoPath)
            total += fileSize

            items.append(VideoItem(
                id: "session_\(session.id)",
                type: .studySession(session),
                localVideoPath: session.localVideoPath,
                localThumbnailPath: session.localThumbnailPath,
                goalTitle: goalLookup[session.goalId],
                todoTitle: nil,
                durationMinutes: session.durationMinutes,
                createdAt: session.createdDate,
                fileSize: fileSize
            ))
        }

        // Add goal todos with videos
        for todo in goalTodos {
            guard let videoPath = todo.localVideoPath else { continue }
            let fileSize = getFileSize(for: videoPath)
            total += fileSize

            items.append(VideoItem(
                id: "todo_\(todo.id)",
                type: .goalTodo(todo),
                localVideoPath: videoPath,
                localThumbnailPath: todo.localThumbnailPath,
                goalTitle: todo.goalTitle ?? goalLookup[todo.goalId],
                todoTitle: todo.title,
                durationMinutes: todo.videoDurationMinutes,
                createdAt: todo.createdDate,
                fileSize: fileSize
            ))
        }

        // Sort by date, newest first
        items.sort { $0.createdAt > $1.createdAt }

        self.videos = items
        self.totalSize = total
    }

    private func getFileSize(for relativePath: String) -> Int64 {
        guard let url = LocalStorageService.shared.getFullURL(for: relativePath),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    private func deleteSelectedVideos() {
        isDeleting = true

        Task {
            for videoId in selectedIds {
                guard let video = videos.first(where: { $0.id == videoId }) else { continue }

                do {
                    switch video.type {
                    case .studySession(let session):
                        try await ConvexService.shared.deleteStudySession(
                            id: session.id,
                            localVideoPath: session.localVideoPath,
                            localThumbnailPath: session.localThumbnailPath
                        )
                    case .goalTodo(let todo):
                        if let videoPath = todo.localVideoPath {
                            try await ConvexService.shared.removeGoalTodoVideo(
                                id: todo.id,
                                localVideoPath: videoPath,
                                localThumbnailPath: todo.localThumbnailPath
                            )
                        }
                    }
                } catch {
                    print("Failed to delete video: \(error)")
                }
            }

            await MainActor.run {
                isDeleting = false
                selectedIds.removeAll()
                isEditMode = false
                // Reload to refresh the list
                loadVideos()
            }
        }
    }
}

// Helper class to hold cancellables
class VideoStorageDataManager {
    static let shared = VideoStorageDataManager()
    var cancellables = Set<AnyCancellable>()
}

struct VideoRow: View {
    let video: VideoItem
    let isSelected: Bool
    let isEditMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }

            // Thumbnail
            Group {
                if let thumbnailURL = video.thumbnailURL,
                   let uiImage = UIImage(contentsOfFile: thumbnailURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "video.fill")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 80, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.displayTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(video.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(video.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let duration = video.formattedDuration {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(video.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        VideoStorageView()
    }
}
