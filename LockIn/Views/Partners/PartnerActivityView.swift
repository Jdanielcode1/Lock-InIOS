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

    var body: some View {
        List {
            // Partner header
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Text(partner.initials)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.displayName)
                            .font(.title3.bold())

                        Text(partner.partnerEmail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Shared videos
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else if partnerVideos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)

                        Text("No Shared Videos")
                            .font(.headline)

                        Text("\(partner.displayName) hasn't shared any videos with you yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(partnerVideos) { video in
                        Button {
                            playVideo(video)
                        } label: {
                            SharedVideoRow(video: video, isLoading: isLoadingVideo && selectedVideo?.id == video.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                if !partnerVideos.isEmpty {
                    Text("Shared with you")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Partner Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
                }
                print("Failed to get video URL: \(error)")
            }
        }
    }
}

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

            // Close button
            VStack {
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 60)

                    Spacer()
                }
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

struct SharedVideoRow: View {
    let video: SharedVideo
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 64, height: 48)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.contextDescription)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(video.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(video.relativeTimeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
