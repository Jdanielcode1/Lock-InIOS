//
//  TimeLapseRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVFoundation

struct TimeLapseRecorderView: View {
    let goalId: String
    let subtaskId: String?

    @Environment(\.dismiss) var dismiss
    @StateObject private var recorder: TimeLapseRecorder
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadSuccess = false
    @State private var errorMessage: String?

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

                    // Camera preview
                    ZStack {
                        CameraPreview(session: recorder.captureSession)
                            .frame(height: 600)
                            .cornerRadius(AppTheme.cornerRadius)

                        // Camera flip button (shown when not recording)
                        if !recorder.isRecording && recorder.recordedVideoURL == nil {
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
                                            .foregroundColor(.white)

                                        Text("\(recorder.frameCount) frames")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.8))
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
                    .foregroundColor(AppTheme.primaryPurple)
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

    var formattedDuration: String {
        let minutes = Int(recorder.recordingDuration) / 60
        let seconds = Int(recorder.recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
                        .stroke(recorder.isRecording ? Color.red : AppTheme.primaryPurple, lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(recorder.isRecording ? Color.red : AppTheme.primaryPurple)
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

    var finishedRecordingButtons: some View {
        HStack(spacing: 40) {
            // Retake
            Button {
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

            // Upload
            Button {
                Task {
                    await uploadVideo()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 70, height: 70)
                        .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "arrow.up.circle.fill")
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
                    .stroke(AppTheme.lightPurple.opacity(0.3), lineWidth: 12)
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

            Text("Uploading...")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
    }

    private func uploadVideo() async {
        guard let videoURL = recorder.recordedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            // Use actual recording duration for study time
            let studyTimeMinutes = recorder.recordingDuration / 60.0

            // Upload the timelapse video
            let uploadURL = try await ConvexService.shared.generateUploadUrl()
            uploadProgress = 0.4

            let storageId = try await ConvexService.shared.uploadVideo(url: videoURL, uploadUrl: uploadURL)
            uploadProgress = 0.8

            // Create study session with actual recording duration
            _ = try await ConvexService.shared.createStudySession(
                goalId: goalId,
                subtaskId: subtaskId,
                videoStorageId: storageId,
                durationMinutes: studyTimeMinutes
            )

            uploadProgress = 1.0
            uploadSuccess = true

            // Clean up
            try? FileManager.default.removeItem(at: videoURL)

            dismiss()

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0
        }
    }
}

#Preview {
    TimeLapseRecorderView(goalId: "123", subtaskId: nil)
}
