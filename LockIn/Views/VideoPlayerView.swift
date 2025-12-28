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
    @State private var voiceoverError: String?

    private let recorder = TimeLapseRecorder()

    init(session: StudySession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isCompilingVoiceover {
                voiceoverCompilingView
            } else if viewModel.isLoading {
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

                    // Voiceover button overlay (hidden during recording/countdown)
                    if !isRecordingVoiceover && !showVoiceoverCountdown {
                        VStack {
                            Spacer()
                            voiceoverButton
                                .padding(.bottom, 100)
                        }
                    }
                }
                .onAppear {
                    player.play()
                    print("🎬 Started playback")
                }
                .onDisappear {
                    cleanupPlayer()
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

            // Voiceover recording overlay
            if isRecordingVoiceover {
                voiceoverRecordingOverlay
            }

            // Voiceover countdown overlay
            if showVoiceoverCountdown {
                voiceoverCountdownOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isRecordingVoiceover || showVoiceoverCountdown || isCompilingVoiceover)
        .toolbar {
            if !isRecordingVoiceover && !showVoiceoverCountdown && !isCompilingVoiceover {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        cleanupPlayer()
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
        }
        .alert("Save Video", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Error", isPresented: .constant(voiceoverError != nil)) {
            Button("OK") {
                voiceoverError = nil
            }
        } message: {
            if let error = voiceoverError {
                Text(error)
            }
        }
    }

    // MARK: - Voiceover UI Components

    var voiceoverButton: some View {
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
    }

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
        guard let player = viewModel.player else { return }

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
            if let duration = player.currentItem?.duration, duration.isNumeric {
                voiceoverTotalDuration = CMTimeGetSeconds(duration)
            }

            // Add periodic time observer for progress
            voiceoverTimeObserver = player.addPeriodicTimeObserver(
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
            player.seek(to: .zero)
            player.play()

            print("🎙️ Started voiceover recording")
        } catch {
            print("❌ Failed to start voiceover recording: \(error)")
            voiceoverError = "Failed to start voiceover: \(error.localizedDescription)"
        }
    }

    private func stopVoiceoverRecording() {
        // Remove time observer
        if let observer = voiceoverTimeObserver {
            viewModel.player?.removeTimeObserver(observer)
            voiceoverTimeObserver = nil
        }

        // Reset progress
        voiceoverProgress = 0
        voiceoverCurrentTime = 0

        voiceoverRecorder?.stop()
        voiceoverRecorder = nil
        viewModel.player?.pause()
        isRecordingVoiceover = false

        print("🎙️ Stopped voiceover recording")

        // Compile video with voiceover
        Task {
            await compileWithVoiceover()
        }
    }

    private func compileWithVoiceover() async {
        guard let voiceoverURL = voiceoverURL,
              let currentVideoURL = viewModel.currentVideoURL else {
            print("❌ Missing voiceover URL or video URL")
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
            let oldVideoPath = session.localVideoPath

            // Update study session in database with new video path
            try await ConvexService.shared.updateStudySessionVideo(
                id: session.id,
                localVideoPath: newVideoPath,
                localThumbnailPath: session.localThumbnailPath
            )

            // Delete old video file
            LocalStorageService.shared.deleteVideo(at: oldVideoPath)

            // Clean up temp files
            try? FileManager.default.removeItem(at: voiceoverURL)
            try? FileManager.default.removeItem(at: outputURL)

            // Update viewModel and refresh player
            await MainActor.run {
                self.voiceoverURL = nil
                hasVoiceoverAdded = true
                viewModel.reloadVideo(with: newVideoPath)
            }

            print("✅ Voiceover added successfully")
        } catch {
            print("❌ Failed to add voiceover: \(error)")
            await MainActor.run {
                voiceoverError = "Failed to add voiceover: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isCompilingVoiceover = false
        }
    }

    private func cleanupPlayer() {
        // Remove time observer if exists
        if let observer = voiceoverTimeObserver {
            viewModel.player?.removeTimeObserver(observer)
            voiceoverTimeObserver = nil
        }
        viewModel.player?.pause()
    }

    private func saveVideoToCameraRoll() {
        guard let videoURL = viewModel.currentVideoURL else {
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
    @Published var currentVideoURL: URL?

    private var session: StudySession
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
        currentVideoURL = videoURL

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

    func reloadVideo(with newVideoPath: String) {
        // Update the local video path
        let newURL = LocalStorageService.shared.getFullURL(for: newVideoPath)
        currentVideoURL = newURL

        guard let videoURL = newURL else {
            errorMessage = "Could not load updated video"
            return
        }

        // Create new player
        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        // Observe player status
        playerItemObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    print("✅ Updated video ready to play!")
                case .failed:
                    print("❌ Playback failed: \(item.error?.localizedDescription ?? "Unknown")")
                    self?.errorMessage = "Playback failed: \(item.error?.localizedDescription ?? "Unknown")"
                default:
                    break
                }
            }
        }

        player = newPlayer
        newPlayer.play()
        print("✅ Reloaded video with voiceover!")
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
