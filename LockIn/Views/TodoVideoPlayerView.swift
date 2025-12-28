//
//  TodoVideoPlayerView.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Photos

struct TodoVideoPlayerView: View {
    let todo: TodoItem

    @Environment(\.dismiss) var dismiss
    @State private var currentVideoURL: URL
    @State private var player: AVPlayer?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Voiceover recording state
    @State private var isRecordingVoiceover = false
    @State private var voiceoverRecorder: AVAudioRecorder?
    @State private var voiceoverURL: URL?
    @State private var isCompilingVoiceover = false
    @State private var showVoiceoverCountdown = false
    @State private var voiceoverCountdownNumber = 3
    @State private var voiceoverProgress: Double = 0
    @State private var voiceoverCurrentTime: TimeInterval = 0
    @State private var voiceoverTotalDuration: TimeInterval = 0
    @State private var voiceoverTimeObserver: Any?
    @State private var hasVoiceoverAdded = false

    private let recorder = TimeLapseRecorder()

    init(videoURL: URL, todo: TodoItem) {
        self.todo = todo
        _currentVideoURL = State(initialValue: videoURL)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isCompilingVoiceover {
                voiceoverCompilingView
            } else if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Main overlay (hidden during voiceover recording)
            if !isRecordingVoiceover && !showVoiceoverCountdown && !isCompilingVoiceover {
                mainOverlay
            }

            // Voiceover recording overlay
            if isRecordingVoiceover {
                voiceoverRecordingOverlay
            }

            // Voiceover countdown overlay
            if showVoiceoverCountdown {
                voiceoverCountdownOverlay
            }
        }
        .alert("Save Video", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
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
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Main Overlay

    var mainOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    cleanupPlayer()
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

            // Voiceover button at bottom
            Button {
                startVoiceoverCountdown()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasVoiceoverAdded ? "arrow.counterclockwise" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(hasVoiceoverAdded ? "Re-record Voiceover" : "Add Voiceover")
                        .font(.system(size: 17, weight: .semibold))
                    if hasVoiceoverAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 280, height: 56)
                .background(hasVoiceoverAdded ? Color.orange.opacity(0.8) : Color.orange)
                .cornerRadius(28)
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Voiceover Views

    var voiceoverCompilingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)

            Text("Adding Voiceover...")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    var voiceoverRecordingOverlay: some View {
        VStack {
            // Top: Recording indicator + time
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .modifier(PulsingModifier())

                    Text("Recording Voiceover")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Time display
                Text("\(formatVoiceoverTime(voiceoverCurrentTime)) / \(formatVoiceoverTime(voiceoverTotalDuration))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.7))

            Spacer()

            // Progress bar at bottom
            VStack(spacing: 16) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * voiceoverProgress, height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 20)

                // Stop button
                Button {
                    stopVoiceoverRecording()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Stop Recording")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 220, height: 56)
                    .background(Color.red)
                    .cornerRadius(28)
                }
            }
            .padding(.bottom, 40)
        }
    }

    var voiceoverCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("\(voiceoverCountdownNumber)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Get ready to narrate...")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Voiceover Functions

    private func formatVoiceoverTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startVoiceoverCountdown() {
        showVoiceoverCountdown = true
        voiceoverCountdownNumber = 3

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            voiceoverCountdownNumber -= 1
            if voiceoverCountdownNumber == 0 {
                timer.invalidate()
                showVoiceoverCountdown = false
                beginVoiceoverCapture()
            }
        }
    }

    private func beginVoiceoverCapture() {
        // Setup audio recorder
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            voiceoverRecorder = try AVAudioRecorder(url: url, settings: settings)
            voiceoverRecorder?.record()
            voiceoverURL = url
            isRecordingVoiceover = true

            // Get video duration for progress tracking
            if let duration = player?.currentItem?.duration, duration.isNumeric {
                voiceoverTotalDuration = CMTimeGetSeconds(duration)
            }

            // Add periodic time observer for progress
            voiceoverTimeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [self] time in
                let currentTime = CMTimeGetSeconds(time)
                voiceoverCurrentTime = currentTime
                if voiceoverTotalDuration > 0 {
                    voiceoverProgress = currentTime / voiceoverTotalDuration
                }
            }

            // Reset and play video from start
            player?.seek(to: .zero)
            player?.play()

            print("🎙️ Started voiceover recording")
        } catch {
            print("❌ Failed to start voiceover recording: \(error)")
            errorMessage = "Failed to start voiceover: \(error.localizedDescription)"
        }
    }

    private func stopVoiceoverRecording() {
        // Remove time observer
        if let observer = voiceoverTimeObserver {
            player?.removeTimeObserver(observer)
            voiceoverTimeObserver = nil
        }

        // Reset progress
        voiceoverProgress = 0
        voiceoverCurrentTime = 0

        voiceoverRecorder?.stop()
        voiceoverRecorder = nil
        player?.pause()
        isRecordingVoiceover = false

        print("🎙️ Stopped voiceover recording")

        // Compile video with voiceover
        Task {
            await compileWithVoiceover()
        }
    }

    private func compileWithVoiceover() async {
        guard let voiceoverURL = voiceoverURL else {
            print("❌ Missing voiceover URL")
            return
        }

        await MainActor.run {
            isCompilingVoiceover = true
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        do {
            try await recorder.addVoiceoverToVideo(
                videoURL: currentVideoURL,
                voiceoverURL: voiceoverURL,
                outputURL: outputURL
            )

            // Save new video to local storage
            let newVideoPath = try LocalStorageService.shared.saveVideo(from: outputURL)

            // Get old video path to delete later
            let oldVideoPath = todo.localVideoPath

            // Update todo in database with new video path
            try await ConvexService.shared.attachVideoToTodo(
                id: todo.id,
                localVideoPath: newVideoPath,
                localThumbnailPath: todo.localThumbnailPath
            )

            // Delete old video file
            if let oldPath = oldVideoPath {
                LocalStorageService.shared.deleteVideo(at: oldPath)
            }

            // Clean up temp files
            try? FileManager.default.removeItem(at: voiceoverURL)
            try? FileManager.default.removeItem(at: outputURL)

            // Update current video URL and refresh player
            await MainActor.run {
                if let newURL = LocalStorageService.shared.getFullURL(for: newVideoPath) {
                    currentVideoURL = newURL
                }
                self.voiceoverURL = nil
                hasVoiceoverAdded = true
                setupPlayer()
            }

            print("✅ Voiceover added successfully")
        } catch {
            print("❌ Failed to add voiceover: \(error)")
            await MainActor.run {
                errorMessage = "Failed to add voiceover: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isCompilingVoiceover = false
        }
    }

    // MARK: - Player Functions

    private func setupPlayer() {
        player = AVPlayer(url: currentVideoURL)
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

    private func cleanupPlayer() {
        // Remove time observer if exists
        if let observer = voiceoverTimeObserver {
            player?.removeTimeObserver(observer)
            voiceoverTimeObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func saveVideoToCameraRoll() {
        guard FileManager.default.fileExists(atPath: currentVideoURL.path) else {
            saveAlertMessage = "Video file not found"
            showingSaveAlert = true
            return
        }

        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: currentVideoURL)
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
