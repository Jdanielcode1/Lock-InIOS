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
    var onResume: (() -> Void)?  // Callback when Resume is tapped

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
    @State private var showShareSheet = false

    // Notes state
    @State private var editingNotes: String = ""
    @State private var showNotesEditor = false
    @State private var isNotesExpanded = false
    @State private var isSavingNotes = false

    private let recorder = TimeLapseRecorder()

    init(videoURL: URL, todo: TodoItem, onResume: (() -> Void)? = nil) {
        self.todo = todo
        self.onResume = onResume
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
        .shareSheet(isPresented: $showShareSheet, videoURL: currentVideoURL) {
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

    // MARK: - Main Overlay

    var mainOverlay: some View {
        VStack(spacing: 0) {
            // Top bar - minimal
            HStack(spacing: 12) {
                Button {
                    cleanupPlayer()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // Action icons - compact row
                HStack(spacing: 8) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button {
                        saveVideoToCameraRoll()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .disabled(isSaving)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

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
                            dismiss()
                            onResume?()
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
                        editingNotes = todo.videoNotes ?? ""
                        showNotesEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 13, weight: .semibold))
                            Text(todo.videoNotes?.isEmpty == false ? "Edit" : "Notes")
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Notes Section

    var notesSection: some View {
        Group {
            if let notes = todo.videoNotes, !notes.isEmpty {
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
                try await ConvexService.shared.updateTodoVideoNotes(
                    todoId: todo.id,
                    videoNotes: notesToSave
                )
                print("Notes saved successfully")
            } catch {
                print("Failed to save notes: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save notes: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isSavingNotes = false
            }
        }
    }

    // MARK: - Voiceover Views

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
            videoNotes: nil,
            createdAt: Date().timeIntervalSince1970 * 1000
        )
    )
}
