//
//  TimeLapseRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct TimeLapseRecorderView: View {
    let goalId: String
    let subtaskId: String?

    @Environment(\.dismiss) var dismiss
    @StateObject private var recorder: TimeLapseRecorder
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    @State private var previewThumbnail: UIImage?
    @State private var player: AVPlayer?

    private let videoService = VideoService.shared

    init(goalId: String, subtaskId: String?) {
        self.goalId = goalId
        self.subtaskId = subtaskId
        _recorder = StateObject(wrappedValue: TimeLapseRecorder())
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Camera preview or video preview
                    if recorder.recordedVideoURL != nil {
                        // Video preview after recording
                        videoPreviewView
                            .padding(.horizontal)
                    } else {
                        ZStack {
                            CameraPreview(session: recorder.captureSession)
                                .frame(maxWidth: .infinity, maxHeight: isLandscape ? 400 : 600)
                                .cornerRadius(AppTheme.cornerRadius)

                            // Camera flip button (shown when not recording)
                            if !recorder.isRecording {
                                VStack {
                                    HStack {
                                        Spacer()

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
                                    .padding()

                                    Spacer()
                                }
                            }

                            // Recording overlay
                            if recorder.isRecording {
                                VStack {
                                    HStack {
                                        // Recording indicator with capture rate
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 12, height: 12)

                                                Text("TIMELAPSE")
                                                    .font(AppTheme.headlineFont)
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black, radius: 2)
                                            }

                                            Text(recorder.currentCaptureRate)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(8)

                                        Spacer()

                                        // Duration + Frame count
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(formattedDuration)
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(isApproachingLimit ? .orange : .white)

                                            Text("\(recorder.frameCount) frames")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.8))

                                            if isApproachingLimit {
                                                Text("Max 4h")
                                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(8)
                                    }
                                    .padding()

                                    Spacer()
                                }
                            }
                        }
                        .playfulCard()
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Controls
                    if isUploading {
                        uploadProgressView
                    } else if recorder.recordedVideoURL != nil {
                        finishedRecordingButtons
                    } else {
                        recordingButton
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        recorder.cleanup()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.actionBlue)
                }
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
        .onAppear {
            Task {
                await recorder.setupCamera()
            }
        }
        .onDisappear {
            recorder.cleanup()
        }
    }

    var isLandscape: Bool {
        recorder.deviceOrientation == .landscapeLeft || recorder.deviceOrientation == .landscapeRight
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

    var isApproachingLimit: Bool {
        recorder.recordingDuration >= 3.5 * 60 * 60 // 3.5 hours
    }

    var recordingButton: some View {
        HStack {
            Spacer()

            Button {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(recorder.isRecording ? Color.red : AppTheme.actionBlue, lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(recorder.isRecording ? Color.red : AppTheme.actionBlue)
                        .frame(width: 80, height: 80)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }

            Spacer()
        }
    }

    var videoPreviewView: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: isLandscape ? 400 : 600)
                    .clipped()
                    .cornerRadius(AppTheme.cornerRadius)
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: isLandscape ? 400 : 600)
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                            Text("Loading preview...")
                                .font(AppTheme.captionFont)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }

            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(formattedDuration)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .playfulCard()
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        guard let videoURL = recorder.recordedVideoURL else { return }
        player = AVPlayer(url: videoURL)
    }

    var finishedRecordingButtons: some View {
        HStack(spacing: 40) {
            // Retake
            Button {
                player = nil
                previewThumbnail = nil
                recorder.clearFrames()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackground)
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 30))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            // Save
            Button {
                Task {
                    await saveVideo()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 70, height: 70)
                        .shadow(color: AppTheme.actionBlue.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
        }
    }

    var uploadProgressView: some View {
        VStack(spacing: 24) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppTheme.borderLight, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(
                        AppTheme.energyGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(AppTheme.smoothAnimation, value: uploadProgress)

                Text("\(Int(uploadProgress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Text("Saving...")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
    }

    private func saveVideo() async {
        guard let videoURL = recorder.recordedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            // Use actual recording duration for study time
            let studyTimeMinutes = recorder.recordingDuration / 60.0
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

            // Create study session with local path
            _ = try await ConvexService.shared.createStudySession(
                goalId: goalId,
                subtaskId: subtaskId,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath,
                durationMinutes: studyTimeMinutes
            )

            uploadProgress = 1.0
            uploadSuccess = true

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
    TimeLapseRecorderView(goalId: "123", subtaskId: nil)
}
