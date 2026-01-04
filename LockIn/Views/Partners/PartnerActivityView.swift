//
//  PartnerActivityView.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI
import Combine
import AVKit

struct PartnerActivityView: View {
    let partner: Partner
    @State private var partnerVideos: [SharedVideo] = []
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedVideo: SharedVideo?
    @State private var videoURL: URL?
    @State private var isLoadingVideo = false
    @State private var showVideoPlayer = false
    @State private var isPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Partner header card
                PartnerHeaderCard(partner: partner, videoCount: partnerVideos.count)
                    .scaleUp(isPresented: isPresented)

                // Videos section
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding(.vertical, 60)
                    }
                } else if partnerVideos.isEmpty {
                    ActivityEmptyState(partnerName: partner.displayName)
                        .slideUp(isPresented: isPresented, delay: 0.2)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        // Section header
                        HStack {
                            Text("Shared Videos")
                                .font(.headline)
                            Spacer()
                            Text("\(partnerVideos.count) session\(partnerVideos.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)

                        // Video cards
                        LazyVStack(spacing: 16) {
                            ForEach(Array(partnerVideos.enumerated()), id: \.element.id) { index, video in
                                SharedVideoCard(
                                    video: video,
                                    isLoading: isLoadingVideo && selectedVideo?.id == video.id
                                ) {
                                    playVideo(video)
                                }
                                .slideUp(isPresented: isPresented, delay: 0.1 + Double(index) * 0.05)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Partner Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.smooth.delay(0.1)) {
                isPresented = true
            }
            subscribeToPartnerVideos()
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let url = videoURL {
                SharedVideoPlayerView(videoURL: url, title: selectedVideo?.contextDescription ?? "Shared Video")
            }
        }
    }

    private func subscribeToPartnerVideos() {
        ConvexService.shared.getPartnerActivity(partnerId: partner.partnerId)
            .receive(on: DispatchQueue.main)
            .sink { videos in
                self.partnerVideos = videos
                self.isLoading = false
            }
            .store(in: &cancellables)
    }

    private func playVideo(_ video: SharedVideo) {
        HapticFeedback.light()
        selectedVideo = video
        isLoadingVideo = true

        Task {
            do {
                let urlString = try await ConvexService.shared.getSharedVideoUrl(videoId: video.id)
                await MainActor.run {
                    if let url = URL(string: urlString) {
                        self.videoURL = url
                        self.showVideoPlayer = true
                    }
                    self.isLoadingVideo = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingVideo = false
                    HapticFeedback.error()
                }
                print("Failed to get video URL: \(error)")
            }
        }
    }
}

// MARK: - Partner Header Card

private struct PartnerHeaderCard: View {
    let partner: Partner
    let videoCount: Int

    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            PartnerAvatar(partner: partner, size: 72)

            // Name and email
            VStack(spacing: 4) {
                Text(partner.displayName)
                    .font(.title2.weight(.bold))

                Text(partner.partnerEmail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 32) {
                PartnerStatItem(value: "\(videoCount)", label: "Videos", icon: "video.fill", color: .green)
                PartnerStatItem(value: "Active", label: "Status", icon: "checkmark.circle.fill", color: .blue)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }
}

private struct PartnerStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Video Card (Rich)

private struct SharedVideoCard: View {
    let video: SharedVideo
    let isLoading: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail with 16:9 aspect ratio
                ZStack {
                    // Background gradient (simulating video thumbnail)
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(UIColor.tertiarySystemFill),
                                    Color(UIColor.quaternarySystemFill)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Gradient overlay at bottom
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium))

                    // Center play button
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 56, height: 56)

                            Image(systemName: "play.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .offset(x: 2) // Visual centering
                        }
                    }

                    // Duration badge - bottom left
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                Text(video.formattedDuration)
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.6))
                            )

                            Spacer()
                        }
                        .padding(10)
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium))

                // Metadata below thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.contextDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(video.relativeTimeString)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 12)
            }
        }
        .buttonStyle(PressButtonStyle(scale: 0.98, enableHaptic: false))
    }
}

// MARK: - Activity Empty State

private struct ActivityEmptyState: View {
    let partnerName: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 0.3 : 0.6)

                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 64, height: 64)

                    Image(systemName: "video.slash")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("No Videos Yet")
                    .font(.headline)

                Text("\(partnerName) hasn't shared any\nstudy sessions with you yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Video Player

struct SharedVideoPlayerView: View {
    let videoURL: URL
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Overlay controls
            VStack {
                HStack {
                    // Close button
                    Button {
                        HapticFeedback.light()
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressButtonStyle())

                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 60)

                Spacer()
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

#Preview {
    NavigationView {
        PartnerActivityView(partner: Partner(
            _id: "1",
            userId: "user1",
            partnerId: "partner1",
            partnerEmail: "john@example.com",
            partnerName: "John Doe",
            status: .active,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
    }
}
