//
//  PartnerStoryViewer.swift
//  LockIn
//
//  Full-screen Instagram Stories-style viewer for partner videos
//

import SwiftUI
import AVKit
import Combine
import CoreMedia

// MARK: - Story Player ViewModel

@MainActor
class StoryPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isReady = false
    @Published var isLoading = false
    @Published var error: Error?

    private var playerItemObserver: NSKeyValueObservation?
    private var currentLoadTask: Task<Void, Never>?
    private var currentVideoId: String?

    func loadVideo(videoId: String, urlFetcher: @escaping () async throws -> String) {
        // Cancel any in-flight load
        currentLoadTask?.cancel()

        // Skip if same video already loaded
        guard videoId != currentVideoId else { return }

        // Reset state
        isReady = false
        isLoading = true
        error = nil
        cleanupPlayer()
        currentVideoId = videoId

        currentLoadTask = Task {
            do {
                let urlString = try await urlFetcher()

                // Check cancellation
                guard !Task.isCancelled else { return }

                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }

                await setupPlayer(with: url)
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.error = error
            }
        }
    }

    private func setupPlayer(with url: URL) async {
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)

        // Optimize for remote streaming - don't wait to minimize stalling
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        // Observe player item status - only mark ready when ACTUALLY ready
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isReady = true
                    self.isLoading = false
                    self.player?.play()
                case .failed:
                    self.isLoading = false
                    self.error = item.error
                default:
                    break
                }
            }
        }

        self.player = newPlayer
    }

    private func cleanupPlayer() {
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        player?.pause()
        player = nil
    }

    func cleanup() {
        currentLoadTask?.cancel()
        cleanupPlayer()
        currentVideoId = nil
        isReady = false
        isLoading = false
        error = nil
    }

    func pause() {
        player?.pause()
    }

    func play() {
        player?.play()
    }

    func seekToStart() {
        player?.seek(to: .zero)
    }
}

// MARK: - Partner Story Viewer

struct PartnerStoryViewer: View {
    let partner: Partner
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
                    EmptyStoriesView(partnerName: partner.displayName)
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

                        // UI overlay
                        VStack(spacing: 0) {
                            // Progress bar
                            StoryProgressBar(
                                total: videos.count,
                                current: currentIndex
                            )
                            .padding(.horizontal, 8)
                            .padding(.top, 12)

                            // Header
                            StoryHeader(
                                partner: partner,
                                video: videos.indices.contains(currentIndex) ? videos[currentIndex] : nil,
                                onClose: closeViewer
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer()

                            // Bottom info
                            if videos.indices.contains(currentIndex) {
                                StoryBottomInfo(video: videos[currentIndex])
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
        ConvexService.shared.getPartnerActivity(partnerId: partner.partnerId)
            .receive(on: DispatchQueue.main)
            .sink { videos in
                self.videos = videos
                self.isLoading = false
                if !videos.isEmpty {
                    loadVideo(at: 0)
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

    private func closeViewer() {
        HapticFeedback.light()
        playerViewModel.pause()
        dismiss()
    }
}

// MARK: - Custom Video Player (No Controls)

struct StoryVideoPlayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // CRITICAL: Only update if player instance actually changed
        // This prevents blinking caused by unnecessary reassignment on every SwiftUI redraw
        if uiView.player !== player {
            uiView.player = player
        }
    }

    class PlayerUIView: UIView {
        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspectFill
            backgroundColor = .black
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - Gesture Overlay

struct StoryGestureOverlay: View {
    let geometry: GeometryProxy
    let onTapLeft: () -> Void
    let onTapRight: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void

    @State private var isPressing = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressing {
                            isPressing = true
                            // Start long press timer
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if isPressing {
                                    onLongPressStart()
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        let wasPressing = isPressing
                        isPressing = false

                        // Check if it was a quick tap (not a long press or drag)
                        let dragDistance = abs(value.translation.width) + abs(value.translation.height)
                        if dragDistance < 10 {
                            // It's a tap - determine left or right
                            let midX = geometry.size.width / 2
                            if value.startLocation.x < midX {
                                onTapLeft()
                            } else {
                                onTapRight()
                            }
                        }

                        onLongPressEnd()
                    }
            )
    }
}

// MARK: - Progress Bar

private struct StoryProgressBar: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 3)
            }
        }
    }
}

// MARK: - Story Header

private struct StoryHeader: View {
    let partner: Partner
    let video: SharedVideo?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PartnerAvatar(partner: partner, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let video = video {
                    Text(video.relativeTimeString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

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

private struct StoryBottomInfo: View {
    let video: SharedVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.contextDescription)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                Text(video.formattedDuration)
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.8))

            if let notes = video.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.top, 4)
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
    }
}

// MARK: - Empty Stories View

private struct EmptyStoriesView: View {
    let partnerName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("No videos yet")
                .font(.headline)
                .foregroundStyle(.white)

            Text("\(partnerName) hasn't shared any sessions")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Cancellable Holder

private class CancellableHolder: ObservableObject {
    var cancellables = Set<AnyCancellable>()
}

#Preview {
    PartnerStoryViewer(partner: Partner(
        _id: "1",
        userId: "user1",
        partnerId: "partner1",
        partnerEmail: "alex@example.com",
        partnerName: "Alex Chen",
        status: .active,
        createdAt: Date().timeIntervalSince1970 * 1000
    ))
}
