//
//  TimeLapseRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVFoundation
import AVKit

// Timelapse speed options
enum TimelapseSpeed: String, CaseIterable {
    case normal = "Normal"
    case timelapse = "Timelapse"
    case ultraFast = "Ultra Fast"

    var captureInterval: TimeInterval {
        switch self {
        case .normal: return 1.0 / 30.0  // 30 fps - real-time video
        case .timelapse: return 0.5      // 2 fps - 15x speedup
        case .ultraFast: return 2.0      // 0.5 fps - 60x speedup
        }
    }

    var rateLabel: String {
        switch self {
        case .normal: return "30 fps"
        case .timelapse: return "2 fps"
        case .ultraFast: return "0.5 fps"
        }
    }
}

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
    @State private var selectedSpeed: TimelapseSpeed = .timelapse

    private let videoService = VideoService.shared

    init(goalId: String, subtaskId: String?) {
        self.goalId = goalId
        self.subtaskId = subtaskId
        _recorder = StateObject(wrappedValue: TimeLapseRecorder())
    }

    var body: some View {
        ZStack {
            // Full screen camera or video preview
            Color.black.ignoresSafeArea()

            if recorder.recordedVideoURL != nil {
                // Video preview after recording
                videoPreviewView
            } else {
                // Full screen camera preview
                CameraPreview(session: recorder.captureSession)
                    .ignoresSafeArea()
            }

            // Overlay controls
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

                    // Camera flip button (when not recording)
                    if !recorder.isRecording && recorder.recordedVideoURL == nil {
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

                    // Recording info (when recording)
                    if recorder.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)

                            Text(formattedDuration)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("• \(recorder.frameCount) frames")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
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
                if isUploading {
                    uploadProgressView
                        .padding(.bottom, 60)
                } else if recorder.recordedVideoURL != nil {
                    finishedRecordingButtons
                        .padding(.bottom, 60)
                } else {
                    VStack(spacing: 24) {
                        // Speed selector
                        speedSelector

                        // Record button
                        recordingButton
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            Task {
                await recorder.setupCamera()
                // Set initial capture interval
                recorder.setCaptureInterval(selectedSpeed.captureInterval, rateName: selectedSpeed.rateLabel)
            }
        }
        .onDisappear {
            recorder.cleanup()
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

    var videoPreviewView: some View {
        ZStack {
            // Full screen video player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                // Loading placeholder
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading preview...")
                        .font(AppTheme.captionFont)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
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
