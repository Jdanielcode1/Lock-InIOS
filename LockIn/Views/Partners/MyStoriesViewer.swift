//
//  MyStoriesViewer.swift
//  LockIn
//
//  Full-screen viewer for the user's own shared videos
//

import SwiftUI
import AVKit
import Combine

struct MyStoriesViewer: View {
    @Environment(\.dismiss) var dismiss

    @State private var videos: [SharedVideo] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true
    @State private var dragOffset: CGFloat = 0
    @State private var skippedVideoIds: Set<String> = []
    @State private var showSkippedMessage = false

    @StateObject private var playerViewModel = StoryPlayerViewModel()
    @StateObject private var cancellableHolder = CancellableHolder()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if videos.isEmpty {
                    EmptyMyStoriesView()
                } else {
                    // Main content
                    ZStack {
                        // Video player (custom, no controls)
                        StoryVideoPlayer(player: playerViewModel.player)
                            .ignoresSafeArea()

                        // Loading indicator - show until video is ACTUALLY ready
                        if playerViewModel.isLoading || !playerViewModel.isReady {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        }

                        // Skipped video message
                        if showSkippedMessage {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                Text("Video unavailable, skipping...")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.7))
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Gesture overlay - single layer for all gestures
                        StoryGestureOverlay(
                            geometry: geometry,
                            onTapLeft: goToPrevious,
                            onTapRight: goToNext,
                            onLongPressStart: { playerViewModel.pause() },
                            onLongPressEnd: { playerViewModel.play() }
                        )

                        // Overlay UI
                        VStack(spacing: 0) {
                            // Progress bar
                            MyStoryProgressBar(
                                total: videos.count,
                                current: currentIndex
                            )
                            .padding(.horizontal, 8)
                            .padding(.top, 12)

                            // Header
                            MyStoryHeader(
                                video: videos.indices.contains(currentIndex) ? videos[currentIndex] : nil,
                                onClose: { closeViewer() }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer()

                            // Bottom info with delete option
                            if videos.indices.contains(currentIndex) {
                                MyStoryBottomInfo(
                                    video: videos[currentIndex],
                                    onDelete: { deleteCurrentVideo() }
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                            }
                        }
                    }
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 {
                                    closeViewer()
                                } else {
                                    withAnimation(.spring(response: 0.3)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            loadVideos()
        }
        .onDisappear {
            playerViewModel.cleanup()
        }
        .onReceive(playerViewModel.$error.compactMap { $0 }) { error in
            // Check if video is unavailable
            if error.localizedDescription.contains("VIDEO_UNAVAILABLE") ||
               error.localizedDescription.contains("badURL") {
                if videos.indices.contains(currentIndex) {
                    skippedVideoIds.insert(videos[currentIndex].id)
                }
                showSkippedMessage = true
                HapticFeedback.light()

                // Auto-hide message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSkippedMessage = false
                }

                // Skip to next available
                skipToNextAvailable(from: currentIndex)
            } else {
                print("Failed to load video: \(error)")
            }
        }
    }

    // MARK: - Actions

    private func loadVideos() {
        ConvexService.shared.listMySharedVideos()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { videos in
                // Deduplicate by ID to prevent any duplicate entries
                var seen = Set<String>()
                let uniqueVideos = videos.filter { seen.insert($0.id).inserted }
                self.videos = uniqueVideos
                self.isLoading = false
                if !uniqueVideos.isEmpty {
                    self.loadVideo(at: 0)
                }
            }
            .store(in: &cancellableHolder.cancellables)
    }

    private func loadVideo(at index: Int) {
        guard videos.indices.contains(index) else { return }

        let video = videos[index]

        // Skip if already known to be unavailable
        if skippedVideoIds.contains(video.id) {
            skipToNextAvailable(from: index)
            return
        }

        // Use ViewModel to load video - handles task cancellation, status observation, etc.
        playerViewModel.loadVideo(videoId: video.id) {
            try await ConvexService.shared.getSharedVideoUrl(videoId: video.id)
        }
    }

    private func skipToNextAvailable(from index: Int) {
        // Find next video that isn't skipped
        var nextIndex = index + 1
        while nextIndex < videos.count && skippedVideoIds.contains(videos[nextIndex].id) {
            nextIndex += 1
        }

        if nextIndex < videos.count {
            currentIndex = nextIndex
            loadVideo(at: nextIndex)
        } else {
            // No more available videos, try going back
            var prevIndex = index - 1
            while prevIndex >= 0 && skippedVideoIds.contains(videos[prevIndex].id) {
                prevIndex -= 1
            }

            if prevIndex >= 0 {
                currentIndex = prevIndex
                loadVideo(at: prevIndex)
            } else {
                // No available videos at all
                closeViewer()
            }
        }
    }

    private func goToNext() {
        HapticFeedback.light()
        if currentIndex < videos.count - 1 {
            currentIndex += 1
            loadVideo(at: currentIndex)
        } else {
            closeViewer()
        }
    }

    private func goToPrevious() {
        HapticFeedback.light()
        if currentIndex > 0 {
            currentIndex -= 1
            loadVideo(at: currentIndex)
        } else {
            playerViewModel.seekToStart()
            playerViewModel.play()
        }
    }

    private func deleteCurrentVideo() {
        guard videos.indices.contains(currentIndex) else { return }

        let videoToDelete = videos[currentIndex]
        HapticFeedback.warning()

        Task {
            do {
                try await ConvexService.shared.deleteSharedVideo(videoId: videoToDelete.id)
                await MainActor.run {
                    // Video will be removed via subscription update
                    // Move to next or close if empty
                    if videos.count <= 1 {
                        closeViewer()
                    } else if currentIndex >= videos.count - 1 {
                        currentIndex = max(0, currentIndex - 1)
                    }
                }
            } catch {
                HapticFeedback.error()
                print("Failed to delete video: \(error)")
            }
        }
    }

    private func closeViewer() {
        HapticFeedback.light()
        playerViewModel.pause()
        dismiss()
    }
}

// MARK: - Progress Bar

private struct MyStoryProgressBar: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - Story Header

private struct MyStoryHeader: View {
    let video: SharedVideo?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // "You" avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Your Videos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let video = video {
                    Text(video.relativeTimeString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Story Bottom Info

private struct MyStoryBottomInfo: View {
    let video: SharedVideo
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Context (Goal / Todo)
            Text(video.contextDescription)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                // Duration
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(video.formattedDuration)
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.8))

                // Shared with count
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("Shared with \(video.sharedWithPartnerIds.count)")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.8))

                Spacer()

                // Delete button
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("Delete Video", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This video will be removed from all partners. This action cannot be undone.")
        }
    }
}

// MARK: - Empty State

private struct EmptyMyStoriesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("No shared videos")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Videos you share with partners\nwill appear here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Cancellable Holder

private class CancellableHolder: ObservableObject {
    var cancellables = Set<AnyCancellable>()
}

#Preview {
    MyStoriesViewer()
}
