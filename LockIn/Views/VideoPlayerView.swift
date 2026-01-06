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
    var onResume: (() -> Void)?  // Callback when Resume is tapped
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var videoPlayerSession: VideoPlayerSessionManager
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
    @State private var showShareSheet = false

    // Notes state
    @State private var editingNotes: String = ""
    @State private var showNotesEditor = false
    @State private var isNotesExpanded = false
    @State private var isSavingNotes = false

    private let recorder = TimeLapseRecorder()

    init(session: StudySession, onResume: (() -> Void)? = nil) {
        self.session = session
        self.onResume = onResume
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
                        .font(.body)
                        .foregroundStyle(.white)
                }
            } else if let player = viewModel.player {
                ZStack {
                    // Custom video player view
                    VideoPlayerRepresentable(player: player)
                        .ignoresSafeArea()

                    // Bottom overlay (hidden during recording/countdown)
                    if !isRecordingVoiceover && !showVoiceoverCountdown {
                        VStack {
                            Spacer()

                            // Bottom section
                            VStack(spacing: 16) {
                                // Notes card (tappable)
                                notesSection

                                // Action bar
                                HStack(spacing: 12) {
                                    // Resume button
                                    if onResume != nil {
                                        Button {
                                            cleanupPlayer()
                                            onResume?()  // Container handles endPlayback
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("Resume")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundColor(.black)
                                            .frame(height: 38)
                                            .padding(.horizontal, 16)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                        }
                                    }

                                    // Notes button
                                    Button {
                                        editingNotes = session.notes ?? ""
                                        showNotesEditor = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "note.text")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text(session.notes?.isEmpty == false ? "Edit" : "Notes")
                                                .font(.system(size: 13, weight: .semibold))
                                            if isSavingNotes {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                                    .tint(.white)
                                            }
                                        }
                                        .foregroundColor(.white)
                                        .frame(height: 38)
                                        .padding(.horizontal, 16)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isSavingNotes)

                                    // Voiceover button
                                    voiceoverButton
                                }
                            }
                            .padding(.horizontal, 20)
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
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Close") {
                        videoPlayerSession.endPlayback()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
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
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 4) {
                        Text(session.formattedDuration)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("\(session.durationHours.formattedDuration) study time")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }

                        // Save button
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
        .shareSheet(isPresented: $showShareSheet, videoURL: viewModel.currentVideoURL ?? URL(fileURLWithPath: "")) {
            saveVideoToCameraRoll()
        }
        .sheet(isPresented: $showNotesEditor) {
            VideoNotesSheet(
                notes: $editingNotes,
                onSave: {
                    showNotesEditor = false
                    saveNotes()
                },
                onSkip: {
                    showNotesEditor = false
                },
                isEditing: true
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Notes Section

    var notesSection: some View {
        Group {
            if let notes = session.notes, !notes.isEmpty {
                Button {
                    editingNotes = notes
                    showNotesEditor = true
                } label: {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(isNotesExpanded ? 10 : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .onLongPressGesture(minimumDuration: 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isNotesExpanded.toggle()
                    }
                }
            }
        }
    }

    // MARK: - Notes Functions

    private func saveNotes() {
        guard !isSavingNotes else { return }
        isSavingNotes = true

        Task {
            do {
                let notesToSave = editingNotes.isEmpty ? nil : editingNotes
                try await ConvexService.shared.updateStudySessionNotes(
                    sessionId: session.id,
                    notes: notesToSave
                )
                print("Notes saved successfully")
            } catch {
                print("Failed to save notes: \(error)")
                await MainActor.run {
                    voiceoverError = "Failed to save notes: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isSavingNotes = false
            }
        }
    }

    // MARK: - Voiceover UI Components

    var voiceoverButton: some View {
        Button {
            startVoiceoverCountdown()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasVoiceoverAdded ? "waveform" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(hasVoiceoverAdded ? "Redo" : "Voice")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(hasVoiceoverAdded ? .white : .black)
            .frame(height: 38)
            .padding(.horizontal, 16)
            .background {
                if hasVoiceoverAdded {
                    Capsule().fill(.ultraThinMaterial)
                } else {
                    Capsule().fill(Color.white)
                }
            }
        }
    }

    var voiceoverCompilingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text("Adding voiceover...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var voiceoverRecordingOverlay: some View {
        VStack {
            // Top: Recording indicator
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .modifier(PulsingModifier())

                Text(formatVoiceoverTime(voiceoverCurrentTime))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()

            // Progress bar + Stop
            VStack(spacing: 20) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * voiceoverProgress, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)

                // Stop button
                Button {
                    stopVoiceoverRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 50)
        }
    }

    var voiceoverCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            Text("\(voiceoverCountdownNumber)")
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
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
            goalTodoId: nil,
            localVideoPath: "LockInVideos/test.mp4",
            localThumbnailPath: nil,
            durationMinutes: 30,
            notes: nil,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
    }
}
