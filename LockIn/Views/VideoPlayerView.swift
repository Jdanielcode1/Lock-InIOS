//
//  VideoPlayerView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let session: StudySession
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: VideoPlayerViewModel

    init(session: StudySession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)

                    Text("Loading video...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(.white)
                }
            } else if let player = viewModel.player {
                ZStack {
                    // Custom video player view
                    VideoPlayerRepresentable(player: player)
                        .ignoresSafeArea()

                    // Overlay UI
                    VStack {
                        HStack {
                            Spacer()

                            // Speed indicator
                            Text("6x")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding()
                        }
                        Spacer()
                    }
                }
                .onAppear {
                    // Play at 6x speed for time-lapse effect
                    player.play()
                    player.rate = 6.0
                    print("🎬 Started playback at 6x speed")
                }
                .onDisappear {
                    player.pause()
                }
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text(errorMessage)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Close") {
                        dismiss()
                    }
                    .primaryButton()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    Text(session.formattedDuration)
                        .font(AppTheme.headlineFont)
                        .foregroundColor(.white)

                    Text("\(String(format: "%.1f", session.durationHours))h study time")
                        .font(AppTheme.captionFont)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let session: StudySession
    private let convexService = ConvexService.shared
    private var playerItemObserver: NSKeyValueObservation?

    init(session: StudySession) {
        self.session = session
        loadVideo()
    }

    private func loadVideo() {
        Task {
            do {
                isLoading = true
                print("🎥 Loading video for storageId: \(session.videoStorageId)")

                // Get video URL from Convex
                guard let videoUrlString = try await convexService.getVideoUrl(storageId: session.videoStorageId) else {
                    print("❌ No video URL returned from Convex")
                    errorMessage = "Failed to get video URL - no URL returned"
                    isLoading = false
                    return
                }

                print("🔗 Received video URL: \(videoUrlString)")

                guard let videoUrl = URL(string: videoUrlString) else {
                    print("❌ Invalid URL string: \(videoUrlString)")
                    errorMessage = "Invalid video URL format"
                    isLoading = false
                    return
                }

                print("✅ Creating AVPlayer with URL: \(videoUrl)")

                // Create player
                let playerItem = AVPlayerItem(url: videoUrl)
                let newPlayer = AVPlayer(playerItem: playerItem)

                // Enable automatic playback
                newPlayer.automaticallyWaitsToMinimizeStalling = false

                // Observe player status
                playerItemObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] item, change in
                    Task { @MainActor in
                        print("📊 Player status changed: \(item.status.rawValue)")

                        switch item.status {
                        case .readyToPlay:
                            print("✅ Player ready to play!")
                            print("📹 Video size: \(item.presentationSize)")
                            print("⏱️ Video duration: \(CMTimeGetSeconds(item.duration)) seconds")
                            if let tracks = item.asset.tracks(withMediaType: .video).first {
                                print("🎬 Video track: \(tracks)")
                            }
                        case .failed:
                            print("❌ Player failed!")
                            if let error = item.error {
                                print("❌ Error: \(error)")
                                print("❌ Error domain: \(error._domain)")
                                print("❌ Error code: \(error._code)")
                                print("❌ Localized description: \(error.localizedDescription)")
                                if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                                    print("❌ Underlying error: \(underlyingError)")
                                }
                            }

                            // Check access log
                            if let accessLog = item.accessLog() {
                                print("📊 Access Log Events: \(accessLog.events.count)")
                                for event in accessLog.events {
                                    print("  - URI: \(event.uri ?? "nil")")
                                    print("  - Bytes transferred: \(event.numberOfBytesTransferred)")
                                    print("  - Stalls: \(event.numberOfStalls)")
                                }
                            }

                            // Check error log
                            if let errorLog = item.errorLog() {
                                print("❌ Error Log Events: \(errorLog.events.count)")
                                for event in errorLog.events {
                                    print("  - Error domain: \(event.errorDomain ?? "nil")")
                                    print("  - Error code: \(event.errorStatusCode)")
                                    print("  - URI: \(event.uri ?? "nil")")
                                }
                            }

                            self?.errorMessage = "Video playback failed: \(item.error?.localizedDescription ?? "Unknown error")"
                        case .unknown:
                            print("⏳ Player status unknown")
                        @unknown default:
                            print("⚠️ Unknown player status")
                            break
                        }
                    }
                }

                player = newPlayer

                isLoading = false
                print("✅ Video player ready!")

                // Check if URL is accessible
                print("🔍 Checking URL accessibility...")
                Task {
                    do {
                        let (data, response) = try await URLSession.shared.data(from: videoUrl)
                        if let httpResponse = response as? HTTPURLResponse {
                            print("📡 HTTP Status: \(httpResponse.statusCode)")
                            print("📡 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
                            print("📡 Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "nil")")
                            print("📦 Downloaded \(data.count) bytes")
                        }
                    } catch {
                        print("❌ Failed to fetch URL: \(error)")
                    }
                }

            } catch {
                print("❌ Error loading video: \(error)")
                errorMessage = "Failed to load video: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// Custom VideoPlayer UIViewControllerRepresentable for playback rate control
struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    NavigationView {
        VideoPlayerView(session: StudySession(
            _id: "1",
            goalId: "123",
            subtaskId: nil,
            videoStorageId: "abc",
            thumbnailStorageId: nil,
            durationMinutes: 30,
            uploadedAt: Date().timeIntervalSince1970 * 1000
        ))
    }
}
