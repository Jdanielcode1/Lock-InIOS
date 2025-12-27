//
//  TodoRecorderView.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct TodoRecorderView: View {
    let todo: TodoItem
    @ObservedObject var viewModel: TodoViewModel

    @Environment(\.dismiss) var dismiss
    @StateObject private var recorder = TimeLapseRecorder()
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var player: AVPlayer?
    @State private var selectedSpeed: TimelapseSpeed = .timelapse

    private let videoService = VideoService.shared

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if recorder.recordedVideoURL != nil {
                // YouTube-style preview after recording
                previewCompletedView
            } else {
                // Full screen camera preview
                CameraPreview(session: recorder.captureSession)
                    .ignoresSafeArea()

                // Camera overlay controls
                cameraOverlayControls
            }
        }
        .onAppear {
            // Allow landscape orientation in recorder
            OrientationManager.shared.allowAllOrientations()

            Task {
                await recorder.setupCamera()
                recorder.setCaptureInterval(selectedSpeed.captureInterval, rateName: selectedSpeed.rateLabel)
            }
        }
        .onDisappear {
            recorder.cleanup()
            // Lock back to portrait when leaving
            OrientationManager.shared.lockToPortrait()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Camera Overlay Controls

    var cameraOverlayControls: some View {
        VStack {
            // Top bar
            HStack {
                // Cancel button
                Button {
                    recorder.cleanup()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                }

                Spacer()

                // Todo title indicator
                if !recorder.isRecording {
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                }

                // Audio toggle button
                Button {
                    recorder.toggleAudio()
                } label: {
                    Image(systemName: recorder.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(recorder.isAudioEnabled ? .white : .red)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }

                // Camera flip button (when not recording)
                if !recorder.isRecording {
                    Button {
                        recorder.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }

                // Recording info
                if recorder.isRecording {
                    HStack(spacing: 8) {
                        if recorder.isPaused {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                        }

                        Text(formattedDuration)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if recorder.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            Text("• \(recorder.frameCount) frames")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()

            // Bottom controls
            VStack(spacing: 24) {
                // Speed selector
                speedSelector

                // Recording controls
                HStack(spacing: 40) {
                    // Pause button (only visible when recording)
                    if recorder.isRecording {
                        pauseButton
                    }

                    // Record/Stop button
                    recordingButton

                    // Spacer for balance when recording
                    if recorder.isRecording {
                        Color.clear
                            .frame(width: 56, height: 56)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Preview Completed View (YouTube-style)

    var previewCompletedView: some View {
        VStack(spacing: 0) {
            // Close button at top
            HStack {
                Button {
                    recorder.cleanup()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()

            // Video player in a contained box
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(recordedInLandscape ? 16/9 : 9/16, contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * (recordedInLandscape ? 0.35 : 0.5))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .onAppear {
                        player.play()
                    }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(recordedInLandscape ? 16/9 : 9/16, contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * (recordedInLandscape ? 0.35 : 0.5))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                    )
                    .padding(.horizontal, 20)
            }

            // Todo info card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.successGreen)

                    Text(todo.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Spacer()
                }

                if let description = todo.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()

            // Action buttons
            if isUploading {
                uploadProgressView
                    .padding(.bottom, 40)
            } else {
                HStack(spacing: 20) {
                    // Retake button
                    Button {
                        player?.pause()
                        player = nil
                        recorder.clearFrames()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Retake")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(16)
                    }

                    // Save button
                    Button {
                        Task {
                            await saveVideoAndCompleteTodo()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Complete")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.successGreen)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    var formattedDuration: String {
        let hours = Int(recorder.recordingDuration) / 3600
        let minutes = (Int(recorder.recordingDuration) % 3600) / 60
        let seconds = Int(recorder.recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var recordedInLandscape: Bool {
        recorder.recordingOrientation == .landscapeLeft || recorder.recordingOrientation == .landscapeRight
    }

    var speedSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimelapseSpeed.allCases, id: \.self) { speed in
                Button {
                    selectedSpeed = speed
                    recorder.setCaptureInterval(speed.captureInterval, rateName: speed.rateLabel)
                } label: {
                    Text(speed.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedSpeed == speed ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedSpeed == speed ? Color.white : Color.black.opacity(0.5))
                        .cornerRadius(20)
                }
            }
        }
    }

    var pauseButton: some View {
        Button {
            if recorder.isPaused {
                recorder.resumeRecording()
            } else {
                recorder.pauseRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 56, height: 56)

                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    var recordingButton: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
            } else {
                recorder.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.white)
                    .frame(width: recorder.isRecording ? 32 : 64, height: recorder.isRecording ? 32 : 64)
                    .cornerRadius(recorder.isRecording ? 8 : 32)
                    .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
            }
        }
    }

    private func setupPlayer() {
        guard let videoURL = recorder.recordedVideoURL else { return }
        player = AVPlayer(url: videoURL)
    }

    var uploadProgressView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(
                        AppTheme.successGreen,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: uploadProgress)

                Text("\(Int(uploadProgress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text("Saving...")
                .font(AppTheme.headlineFont)
                .foregroundColor(.white)
        }
        .padding()
    }

    private func saveVideoAndCompleteTodo() async {
        guard let videoURL = recorder.recordedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            uploadProgress = 0.2

            // Save video to local storage
            let localVideoPath = try LocalStorageService.shared.saveVideo(from: videoURL)
            uploadProgress = 0.5

            // Generate and save thumbnail
            var localThumbnailPath: String? = nil
            if let fullURL = LocalStorageService.shared.getFullURL(for: localVideoPath) {
                if let thumbnail = try? await videoService.generateThumbnail(from: fullURL) {
                    localThumbnailPath = try? LocalStorageService.shared.saveThumbnail(thumbnail)
                }
            }
            uploadProgress = 0.7

            // Attach video to todo (this also marks it as completed)
            await viewModel.attachVideo(
                to: todo,
                videoPath: localVideoPath,
                thumbnailPath: localThumbnailPath
            )

            uploadProgress = 1.0

            // Clean up temp file
            try? FileManager.default.removeItem(at: videoURL)

            dismiss()

        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0
        }
    }
}

#Preview {
    TodoRecorderView(
        todo: TodoItem(
            _id: "1",
            title: "Complete tutorial",
            description: nil,
            isCompleted: false,
            localVideoPath: nil,
            localThumbnailPath: nil,
            createdAt: Date().timeIntervalSince1970 * 1000
        ),
        viewModel: TodoViewModel()
    )
}
