//
//  TodoRecorderView.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI
import AVFoundation
import AVKit
import AudioToolbox

struct TodoRecorderView: View {
    let todo: TodoItem
    @ObservedObject var viewModel: TodoViewModel

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }
    @StateObject private var recorder = TimeLapseRecorder()
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var player: AVPlayer?
    @State private var selectedSpeed: TimelapseSpeed = .timelapse
    @State private var showMicUnavailableMessage = false

    // Countdown timer state
    @State private var countdownEnabled = false
    @State private var countdownDuration: TimeInterval = 0
    @State private var showCountdownPicker = false
    @State private var selectedMinutes: Int = 0
    @State private var selectedSeconds: Int = 0
    @State private var countdownReachedZero = false
    @State private var alarmEnabled = true
    @State private var alarmPlayer: AVAudioPlayer?
    @State private var showAlarmOverlay = false

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
    @State private var voiceoverCountdownTimer: Timer?
    @State private var videoEndObserver: Any?
    @State private var showShareSheet = false

    // Video notes state
    @State private var pendingNotes: String = ""
    @State private var showNotesSheet: Bool = false

    // Partner sharing state
    @State private var showShareWithPartners = false
    @State private var savedVideoPath: String?
    @State private var savedDurationMinutes: Double = 0
    @StateObject private var partnersViewModel = PartnersViewModel()

    // Privacy mode
    @StateObject private var privacyManager = PrivacyModeManager()

    private let videoService = VideoService.shared

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if recorder.isCompilingVideo {
                // Video compiling animation
                compilingVideoView
            } else if recorder.recordedVideoURL != nil {
                // YouTube-style preview after recording
                previewCompletedView
            } else {
                // Full screen camera preview (hidden in stealth mode)
                CameraPreview(session: recorder.captureSession)
                    .ignoresSafeArea()
                    .opacity(privacyManager.shouldHideControls && recorder.isRecording ? 0 : 1)

                // Camera overlay controls (hidden in privacy mode)
                if !privacyManager.shouldHideControls || !recorder.isRecording {
                    cameraOverlayControls
                }

                // Alarm overlay (always show - important for user)
                if showAlarmOverlay {
                    alarmOverlay
                }

                // Mic unavailable toast message (hidden in privacy mode)
                if showMicUnavailableMessage && !privacyManager.shouldHideControls {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Audio only available in Normal mode")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .padding(.top, 140)

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: - Privacy Mode Overlay

                // Stealth stopwatch overlay (shows minimal timer on black screen)
                if privacyManager.shouldHideControls && recorder.isRecording {
                    StealthStopwatchView(
                        recordingDuration: recorder.recordingDuration,
                        onDoubleTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                privacyManager.deactivate()
                            }
                        },
                        onStopRecording: {
                            recorder.stopRecording()
                        }
                    )
                    .transition(.opacity)
                }

                // Privacy toggle always accessible (top-left corner during privacy mode)
                if privacyManager.shouldHideControls && recorder.isRecording {
                    VStack {
                        HStack {
                            PrivacyModeToggle(privacyManager: privacyManager)
                                .padding(.leading, 20)
                                .padding(.top, 60)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Prevent screen from turning off during recording
            UIApplication.shared.isIdleTimerDisabled = true

            // Allow landscape orientation in recorder
            OrientationManager.shared.allowAllOrientations()

            Task {
                await recorder.setupCamera()
                recorder.setCaptureInterval(
                    selectedSpeed.captureInterval,
                    rateName: selectedSpeed.rateLabel,
                    iphoneMode: selectedSpeed.isDynamicInterval
                )
            }
        }
        .onDisappear {
            // Re-enable screen auto-lock
            UIApplication.shared.isIdleTimerDisabled = false

            recorder.cleanup()
            dismissAlarm()

            // Cleanup voiceover state
            cancelVoiceoverCountdown()
            if isRecordingVoiceover {
                cleanupVoiceoverRecording()
            }

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
        .sheet(isPresented: $showCountdownPicker) {
            CountdownPickerSheet(
                selectedMinutes: $selectedMinutes,
                selectedSeconds: $selectedSeconds,
                onConfirm: {
                    countdownDuration = TimeInterval(selectedMinutes * 60 + selectedSeconds)
                    countdownReachedZero = false
                    showCountdownPicker = false
                },
                onCancel: {
                    showCountdownPicker = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: recorder.recordingDuration) { _, newDuration in
            // Check if countdown just reached zero
            if countdownEnabled &&
               countdownDuration > 0 &&
               !countdownReachedZero &&
               newDuration >= countdownDuration {
                countdownReachedZero = true
                triggerCountdownAlert()
            }
        }
        .onChange(of: recorder.isRecording) { _, isRecording in
            // Activate/deactivate privacy mode when recording starts/stops
            if isRecording {
                privacyManager.onRecordingStarted()
            } else {
                privacyManager.onRecordingStopped()
            }
        }
        .shareSheet(isPresented: $showShareSheet, videoURL: recorder.recordedVideoURL ?? URL(fileURLWithPath: ""))
        .sheet(isPresented: $showNotesSheet) {
            VideoNotesSheet(
                notes: $pendingNotes,
                onSave: {
                    showNotesSheet = false
                },
                onSkip: {
                    pendingNotes = ""
                    showNotesSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareWithPartners) {
            if let videoURL = recorder.recordedVideoURL {
                ShareWithPartnersSheet(
                    videoURL: videoURL,
                    durationMinutes: recorder.recordingDuration / 60.0,
                    goalTitle: nil,
                    todoTitle: todo.title
                ) { partnerIds in
                    Task {
                        await shareWithPartners(partnerIds: partnerIds)
                    }
                } onSkip: {
                    showShareWithPartners = false
                }
            }
        }
    }

    private func triggerCountdownAlert() {
        // Haptic feedback always
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Only show alarm overlay and play sound if alarm is enabled
        guard alarmEnabled else { return }

        // Show alarm overlay
        showAlarmOverlay = true

        // Play looping alarm sound
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "mp3") {
            // Use custom alarm sound if available
            do {
                alarmPlayer = try AVAudioPlayer(contentsOf: soundURL)
                alarmPlayer?.numberOfLoops = -1 // Loop indefinitely
                alarmPlayer?.play()
            } catch {
                playSystemAlarm()
            }
        } else {
            playSystemAlarm()
        }
    }

    private func playSystemAlarm() {
        // Use system alarm sound with repeated playback
        let systemSoundID: SystemSoundID = 1005 // Alarm sound
        AudioServicesPlaySystemSound(systemSoundID)

        // Set up repeating alarm using timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !showAlarmOverlay {
                timer.invalidate()
                return
            }
            AudioServicesPlaySystemSound(systemSoundID)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func dismissAlarm() {
        showAlarmOverlay = false
        alarmPlayer?.stop()
        alarmPlayer = nil
    }

    // MARK: - Alarm Overlay

    var alarmOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Pulsing alarm icon
                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Time's Up!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("Your countdown has finished")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.8))

                // Dismiss button
                Button {
                    dismissAlarm()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 56)
                        .background(Color.red)
                        .cornerRadius(28)
                }
                .padding(.top, 20)
            }
        }
        .onTapGesture {
            dismissAlarm()
        }
        .transition(.opacity)
    }

    // MARK: - Compiling Video View

    var compilingVideoView: some View {
        VStack(spacing: 32) {
            // Animated film reel icon
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.3)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingModifier())

                Image(systemName: "film.stack")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("Creating Video")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Compiling \(recorder.frameCount) frames...")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
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

                // Buttons row
                HStack(spacing: 16) {
                    // Discard button
                    Button {
                        discardVoiceoverRecording()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(28)
                    }

                    // Stop & save button
                    Button {
                        stopVoiceoverRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 160, height: 56)
                        .background(Color.orange)
                        .cornerRadius(28)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func formatVoiceoverTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var voiceoverCountdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("\(voiceoverCountdownNumber)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white)

                Text("Get ready to narrate...")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))

                Button {
                    cancelVoiceoverCountdown()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                }
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Voiceover Functions

    private func startVoiceoverCountdown() {
        showVoiceoverCountdown = true
        voiceoverCountdownNumber = 3

        voiceoverCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            voiceoverCountdownNumber -= 1
            if voiceoverCountdownNumber == 0 {
                timer.invalidate()
                voiceoverCountdownTimer = nil
                showVoiceoverCountdown = false
                beginVoiceoverCapture()
            }
        }
    }

    private func cancelVoiceoverCountdown() {
        voiceoverCountdownTimer?.invalidate()
        voiceoverCountdownTimer = nil
        showVoiceoverCountdown = false
        voiceoverCountdownNumber = 3
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

            // Add observer for when video ends - auto stop recording
            videoEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { [self] _ in
                if isRecordingVoiceover {
                    stopVoiceoverRecording()
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
        cleanupVoiceoverRecording()

        print("🎙️ Stopped voiceover recording")

        // Compile video with voiceover
        Task {
            await compileWithVoiceover()
        }
    }

    private func discardVoiceoverRecording() {
        cleanupVoiceoverRecording()

        // Clean up the recorded audio file
        if let url = voiceoverURL {
            try? FileManager.default.removeItem(at: url)
        }
        voiceoverURL = nil

        print("🎙️ Discarded voiceover recording")
    }

    private func cleanupVoiceoverRecording() {
        // Remove time observer
        if let observer = voiceoverTimeObserver {
            player?.removeTimeObserver(observer)
            voiceoverTimeObserver = nil
        }

        // Remove video end observer
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }

        // Reset progress
        voiceoverProgress = 0
        voiceoverCurrentTime = 0

        voiceoverRecorder?.stop()
        voiceoverRecorder = nil
        player?.pause()
        isRecordingVoiceover = false
    }

    private func compileWithVoiceover() async {
        guard let videoURL = recorder.recordedVideoURL,
              let voiceoverURL = voiceoverURL else {
            print("❌ Missing video or voiceover URL")
            return
        }

        isCompilingVoiceover = true

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        do {
            try await recorder.addVoiceoverToVideo(
                videoURL: videoURL,
                voiceoverURL: voiceoverURL,
                outputURL: outputURL
            )

            // Clean up old video file
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: voiceoverURL)

            // Update recorder with new video
            await MainActor.run {
                recorder.recordedVideoURL = outputURL
                self.voiceoverURL = nil
                hasVoiceoverAdded = true
                setupPlayer() // Refresh player with new video
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

                // Privacy mode toggle (hide during recording to save space)
                if !recorder.isRecording {
                    PrivacyModeToggle(privacyManager: privacyManager)

                    // Todo title indicator
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                }

                Spacer()

                // Audio toggle button
                Button {
                    if recorder.isAudioAllowed {
                        recorder.toggleAudio()
                    } else {
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)

                        // Show message that mic is only available in Normal mode
                        withAnimation(.spring(response: 0.3)) {
                            showMicUnavailableMessage = true
                        }
                        // Auto-hide after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.spring(response: 0.3)) {
                                showMicUnavailableMessage = false
                            }
                        }
                    }
                } label: {
                    Image(systemName: recorder.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(recorder.isAudioEnabled ? .white : (recorder.isAudioAllowed ? .red : .gray))
                        .padding(12)
                        .background(Color.black.opacity(recorder.isAudioAllowed ? 0.5 : 0.3))
                        .clipShape(Circle())
                }

                // Camera flip button (when not recording)
                if !recorder.isRecording {
                    // Zoom button (only show on back camera with ultra-wide)
                    if recorder.hasUltraWide {
                        Button {
                            recorder.cycleZoom()
                        } label: {
                            Text(zoomLevelText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }

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
                    HStack(spacing: 6) {
                        if recorder.isPaused {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        } else if isOvertime {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                        } else if countdownEnabled && countdownDuration > 0 {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }

                        Text(timerDisplayText)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(isOvertime ? .red : .white)

                        if recorder.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            Text("\(recorder.frameCount)f")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .fixedSize()
                }
            }
            .padding(.horizontal)
            .padding(.top, 60)

            // Countdown timer settings (below top bar, when not recording)
            if !recorder.isRecording {
                countdownTimerSettings
                    .padding(.top, 12)
            }

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

            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(recordedInLandscape ? 16/9 : 9/16, contentMode: .fit)
                    .cornerRadius(16)
                    .frame(maxHeight: UIScreen.main.bounds.height * (recordedInLandscape ? 0.4 : 0.55))
                    .padding(.horizontal, 20)
                    .onAppear {
                        player.play()
                    }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(recordedInLandscape ? 16/9 : 9/16, contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * (recordedInLandscape ? 0.4 : 0.55))
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
                            .foregroundColor(.green)

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
                if isUploading || isCompilingVoiceover {
                    if isCompilingVoiceover {
                        voiceoverCompilingView
                            .padding(.bottom, 40)
                    } else {
                        uploadProgressView
                            .padding(.bottom, 40)
                    }
                } else {
                    VStack(spacing: 16) {
                        // Icon action row
                        HStack(spacing: 0) {
                            // Retake
                            todoActionIconButton(
                                icon: "arrow.counterclockwise",
                                label: "Retake",
                                isActive: false
                            ) {
                                player?.pause()
                                player = nil
                                voiceoverURL = nil
                                hasVoiceoverAdded = false
                                pendingNotes = ""
                                recorder.clearFrames()
                            }

                            // Notes
                            todoActionIconButton(
                                icon: pendingNotes.isEmpty ? "note.text" : "note.text.badge.checkmark",
                                label: "Notes",
                                isActive: !pendingNotes.isEmpty
                            ) {
                                showNotesSheet = true
                            }

                            // Voiceover
                            todoActionIconButton(
                                icon: hasVoiceoverAdded ? "waveform" : "mic.fill",
                                label: hasVoiceoverAdded ? "Re-record" : "Voice",
                                isActive: hasVoiceoverAdded
                            ) {
                                startVoiceoverCountdown()
                            }

                            // Share
                            todoActionIconButton(
                                icon: "square.and.arrow.up",
                                label: "Share",
                                isActive: false
                            ) {
                                showShareSheet = true
                            }

                            // Partners (if available)
                            if !partnersViewModel.partners.isEmpty {
                                todoActionIconButton(
                                    icon: "person.2.fill",
                                    label: "Partners",
                                    isActive: false
                                ) {
                                    showShareWithPartners = true
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)

                        // Primary complete button
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
                            .background(Color.green)
                            .cornerRadius(14)
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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
        .onAppear {
            setupPlayer()
        }
    }

    // MARK: - Action Icon Button Helper

    @ViewBuilder
    private func todoActionIconButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isActive ? Color.accentColor : .white)

                    if isActive {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -10)
                    }
                }

                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? Color.accentColor : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    var formattedDuration: String {
        formatTime(recorder.recordingDuration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // Countdown timer computed properties
    var remainingTime: TimeInterval {
        max(0, countdownDuration - recorder.recordingDuration)
    }

    var isOvertime: Bool {
        countdownEnabled && countdownDuration > 0 && recorder.recordingDuration > countdownDuration
    }

    var zoomLevelText: String {
        let level = recorder.currentZoomLevel
        if level < 1.0 {
            return String(format: ".%d", Int(level * 10))  // ".5" for 0.5x
        } else {
            return String(format: "%.0f", level)  // "1", "2", "3" for 1x, 2x, 3x
        }
    }

    var timerDisplayText: String {
        if countdownEnabled && countdownDuration > 0 {
            if isOvertime {
                return "-" + formatTime(recorder.recordingDuration - countdownDuration)
            }
            return formatTime(remainingTime)
        }
        return formattedDuration
    }

    var formattedCountdownSetting: String {
        formatTime(countdownDuration)
    }

    var recordedInLandscape: Bool {
        recorder.recordingOrientation == .landscapeLeft || recorder.recordingOrientation == .landscapeRight
    }

    var speedSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimelapseSpeed.allCases, id: \.self) { speed in
                Button {
                    selectedSpeed = speed
                    recorder.setCaptureInterval(
                        speed.captureInterval,
                        rateName: speed.rateLabel,
                        iphoneMode: speed.isDynamicInterval
                    )
                } label: {
                    VStack(spacing: 2) {
                        Text(speed.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                        // Show dynamic rate for iPhone Mode when recording
                        if speed == .iphoneMode && selectedSpeed == .iphoneMode && recorder.isRecording {
                            Text(recorder.currentCaptureRate)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedSpeed == speed ? .black.opacity(0.7) : .white.opacity(0.7))
                        }
                    }
                    .foregroundColor(selectedSpeed == speed ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedSpeed == speed ? Color.white : Color.black.opacity(0.5))
                    .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Countdown Timer Settings

    var countdownTimerSettings: some View {
        VStack(spacing: 10) {
            // Timer toggle button with alarm toggle
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        countdownEnabled.toggle()
                        if !countdownEnabled {
                            countdownDuration = 0
                            countdownReachedZero = false
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: countdownEnabled ? "timer.circle.fill" : "timer")
                            .font(.system(size: 16))
                        Text(countdownEnabled && countdownDuration > 0 ? formattedCountdownSetting : "Set Timer")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(countdownEnabled ? Color.accentColor : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(countdownEnabled ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.5))
                    .cornerRadius(20)
                }

                // Alarm toggle (only show when countdown is enabled)
                if countdownEnabled {
                    Button {
                        alarmEnabled.toggle()
                    } label: {
                        Image(systemName: alarmEnabled ? "bell.fill" : "bell.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(alarmEnabled ? .orange : .gray)
                            .padding(10)
                            .background(alarmEnabled ? Color.orange.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Preset buttons (when enabled)
            if countdownEnabled {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                        Button {
                            countdownDuration = TimeInterval(minutes * 60)
                            countdownReachedZero = false
                        } label: {
                            Text("\(minutes)m")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(countdownDuration == TimeInterval(minutes * 60) ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(countdownDuration == TimeInterval(minutes * 60) ? Color.white : Color.black.opacity(0.5))
                                .cornerRadius(16)
                        }
                    }

                    // Custom picker button
                    Button {
                        // Initialize picker with current countdown
                        selectedMinutes = Int(countdownDuration) / 60
                        selectedSeconds = Int(countdownDuration) % 60
                        showCountdownPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
                        .green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: uploadProgress)

                Text("\(Int(uploadProgress * 100))%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Saving...")
                .font(.headline)
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
            let notesToSave = pendingNotes.isEmpty ? nil : pendingNotes
            let speedSegmentsJSON = recorder.getSpeedSegmentsJSON()
            await viewModel.attachVideo(
                to: todo,
                videoPath: localVideoPath,
                thumbnailPath: localThumbnailPath,
                videoNotes: notesToSave,
                speedSegmentsJSON: speedSegmentsJSON
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

    private func shareWithPartners(partnerIds: [String]) async {
        guard let videoURL = recorder.recordedVideoURL else {
            showShareWithPartners = false
            return
        }

        do {
            // Generate thumbnail from first frame
            var thumbnailR2Key: String? = nil
            if let thumbnail = try? await videoService.generateThumbnail(from: videoURL),
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
                // Get upload URL for thumbnail
                let thumbUploadResponse = try await ConvexService.shared.generateUploadUrl()

                var thumbRequest = URLRequest(url: URL(string: thumbUploadResponse.url)!)
                thumbRequest.httpMethod = "PUT"
                thumbRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                thumbRequest.httpBody = thumbnailData

                let (_, thumbResponse) = try await URLSession.shared.data(for: thumbRequest)
                if let httpResponse = thumbResponse as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    thumbnailR2Key = thumbUploadResponse.key
                    try? await ConvexService.shared.syncR2Metadata(key: thumbUploadResponse.key)
                }
            }

            // Get upload URL and key from Convex
            let uploadResponse = try await ConvexService.shared.generateUploadUrl()

            // Upload video to R2
            let videoData = try Data(contentsOf: videoURL)
            var request = URLRequest(url: URL(string: uploadResponse.url)!)
            request.httpMethod = "PUT"
            request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")
            request.httpBody = videoData

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
            }

            // Use the key from the response
            let r2Key = uploadResponse.key

            // Sync metadata with Convex
            try await ConvexService.shared.syncR2Metadata(key: r2Key)

            // Create shared video record
            _ = try await ConvexService.shared.shareVideo(
                r2Key: r2Key,
                thumbnailR2Key: thumbnailR2Key,
                durationMinutes: recorder.recordingDuration / 60.0,
                goalTitle: nil,
                todoTitle: todo.title,
                notes: pendingNotes.isEmpty ? nil : pendingNotes,
                partnerIds: partnerIds
            )

            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                showShareWithPartners = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to share: \(error.localizedDescription)"
                showShareWithPartners = false
            }
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
