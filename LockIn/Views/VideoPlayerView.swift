//
//  VideoPlayerView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Photos

struct VideoPlayerView: View {
    let session: StudySession
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: VideoPlayerViewModel
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false

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
                }
                .onAppear {
                    player.play()
                    print("🎬 Started playback")
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

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveVideoToCameraRoll()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                    }
                }
                .disabled(isSaving)
            }
        }
        .alert("Save Video", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
    }

    private func saveVideoToCameraRoll() {
        guard let videoURL = session.videoURL else {
            saveAlertMessage = "Video file not found"
            showingSaveAlert = true
            return
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            saveAlertMessage = "Video file has been deleted"
            showingSaveAlert = true
            return
        }

        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            isSaving = false
                            if success {
                                saveAlertMessage = "Video saved to Camera Roll"
                            } else {
                                saveAlertMessage = "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
                            }
                            showingSaveAlert = true
                        }
                    }
                } else {
                    isSaving = false
                    saveAlertMessage = "Please allow photo library access in Settings"
                    showingSaveAlert = true
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
    private var playerItemObserver: NSKeyValueObservation?

    init(session: StudySession) {
        self.session = session
        loadVideo()
    }

    private func loadVideo() {
        isLoading = true
        print("🎥 Loading local video: \(session.localVideoPath)")

        // Get local file URL from session
        guard let videoURL = session.videoURL else {
            print("❌ Could not construct video URL")
            errorMessage = "Video file not found"
            isLoading = false
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Video file does not exist at: \(videoURL.path)")
            errorMessage = "Video file has been deleted"
            isLoading = false
            return
        }

        print("✅ Loading video from: \(videoURL.path)")

        // Create player with local file URL
        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        // Observe player status
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    print("✅ Local video ready to play!")
                case .failed:
                    print("❌ Playback failed: \(item.error?.localizedDescription ?? "Unknown")")
                    self?.errorMessage = "Playback failed: \(item.error?.localizedDescription ?? "Unknown")"
                default:
                    break
                }
            }
        }

        player = newPlayer
        isLoading = false
        print("✅ Local video player ready!")
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
            localVideoPath: "LockInVideos/test.mp4",
            localThumbnailPath: nil,
            durationMinutes: 30,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
    }
}
