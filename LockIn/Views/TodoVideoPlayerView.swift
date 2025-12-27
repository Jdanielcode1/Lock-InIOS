//
//  TodoVideoPlayerView.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI
import AVKit
import Photos

struct TodoVideoPlayerView: View {
    let videoURL: URL
    let todo: TodoItem

    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false

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

            // Top bar overlay
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

                    Spacer()

                    // Save button
                    Button {
                        saveVideoToCameraRoll()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(isSaving)

                    // Todo title
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(todo.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if todo.isCompleted {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Completed")
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.successGreen)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 60)

                Spacer()
            }
        }
        .alert("Save Video", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
        player?.play()

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func saveVideoToCameraRoll() {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            saveAlertMessage = "Video file not found"
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

#Preview {
    TodoVideoPlayerView(
        videoURL: URL(string: "https://example.com/video.mp4")!,
        todo: TodoItem(
            _id: "1",
            title: "Complete tutorial",
            description: nil,
            isCompleted: true,
            localVideoPath: "video.mov",
            localThumbnailPath: nil,
            createdAt: Date().timeIntervalSince1970 * 1000
        )
    )
}
