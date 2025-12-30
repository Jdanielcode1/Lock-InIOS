//
//  TimeLapseRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVFoundation
import AVKit
import AudioToolbox

// Timelapse speed options
enum TimelapseSpeed: String, CaseIterable {
    case normal = "Normal"
    case timelapse = "Timelapse"
    case ultraFast = "Ultra Fast"

    var captureInterval: TimeInterval {
        switch self {
        case .normal: return 0.0         // Capture every camera frame (true real-time ~30fps)
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
    let goalTodoId: String?
    let availableTodos: [GoalTodo]

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }
    @StateObject private var recorder: TimeLapseRecorder
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    @State private var previewThumbnail: UIImage?
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
    @State private var showShareSheet = false

    // Todo tracking during session
    @State private var checkedTodoIds: Set<String> = []
    @State private var showTodoList = false

    private let videoService = VideoService.shared

    init(goalId: String, goalTodoId: String?, availableTodos: [GoalTodo] = []) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        self.availableTodos = availableTodos
        _recorder = StateObject(wrappedValue: TimeLapseRecorder())
    }

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
                // Full screen camera preview
                CameraPreview(session: recorder.captureSession)
                    .ignoresSafeArea()

                // Camera overlay controls
                cameraOverlayControls

                // Floating todo checklist (when recording with available todos)
                if !availableTodos.isEmpty && recorder.isRecording {
                    todoChecklistOverlay
                }

                // Alarm overlay
                if showAlarmOverlay {
                    alarmOverlay
                }

                // Mic unavailable toast message
                if showMicUnavailableMessage {
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
            }
        }
        .onAppear {
            // Prevent screen from turning off during recording
            UIApplication.shared.isIdleTimerDisabled = true

            // Allow landscape orientation in recorder
            OrientationManager.shared.allowAllOrientations()

            Task {
                await recorder.setupCamera()
                // Set initial capture interval
                recorder.setCaptureInterval(selectedSpeed.captureInterval, rateName: selectedSpeed.rateLabel)
            }
        }
        .onDisappear {
            // Re-enable screen auto-lock
            UIApplication.shared.isIdleTimerDisabled = false

            recorder.cleanup()
            dismissAlarm()
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
        .onChange(of: recorder.diskSpaceError) { _, newError in
            if let error = newError {
                errorMessage = error
                recorder.diskSpaceError = nil
            }
        }
        .shareSheet(isPresented: $showShareSheet, videoURL: recorder.recordedVideoURL ?? URL(fileURLWithPath: ""))
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

    // MARK: - Todo Checklist Overlay

    var todoChecklistOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                // Collapsed badge (tap to expand)
                if !showTodoList {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showTodoList = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Tasks")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(checkedTodoIds.count)/\(availableTodos.count)")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(checkedTodoIds.isEmpty ? Color.white.opacity(0.2) : Color.green.opacity(0.3))
                                .cornerRadius(10)
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Expanded checklist
                    VStack(alignment: .leading, spacing: 8) {
                        // Header with collapse button
                        HStack {
                            Image(systemName: "checklist")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Tasks")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(checkedTodoIds.count)/\(availableTodos.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    showTodoList = false
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(6)
                            }
                        }
                        .foregroundStyle(.white)

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Scrollable todo list
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(availableTodos) { todo in
                                    Button {
                                        withAnimation(.spring(response: 0.2)) {
                                            if checkedTodoIds.contains(todo.id) {
                                                checkedTodoIds.remove(todo.id)
                                            } else {
                                                checkedTodoIds.insert(todo.id)
                                                // Haptic feedback
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: checkedTodoIds.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundStyle(checkedTodoIds.contains(todo.id) ? .green : .white.opacity(0.6))

                                            Text(todo.title)
                                                .font(.system(size: 14))
                                                .foregroundStyle(checkedTodoIds.contains(todo.id) ? .white.opacity(0.6) : .white)
                                                .strikethrough(checkedTodoIds.contains(todo.id))
                                                .lineLimit(1)

                                            Spacer()

                                            if todo.isRecurring {
                                                Image(systemName: todo.frequency.icon)
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue.opacity(0.8))
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.8))
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .frame(maxWidth: 300)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            // Progress ring with percentage
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: recorder.compilationProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color.accentColor, .green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: recorder.compilationProgress)

                VStack(spacing: 4) {
                    Text("\(Int(recorder.compilationProgress * 100))%")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Image(systemName: "film.stack")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            VStack(spacing: 12) {
                Text("Creating Video")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Processing \(recorder.frameCount) frames...")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))

                // Show stage
                Text(compilationStageText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Warning about not closing the app
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)

                Text("Please keep the app open")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
            .padding(.top, 20)
        }
    }

    var compilationStageText: String {
        let progress = recorder.compilationProgress
        if progress < 0.8 {
            return "Encoding frames..."
        } else if progress < 0.95 {
            return "Adding audio..."
        } else {
            return "Finalizing..."
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
            }
        }
    }

    // MARK: - Voiceover Functions

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
                                .frame(width: 10, height: 10)
                        }

                        Text(timerDisplayText)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(isOvertime ? .red : .white)

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

            // Low disk space warning (below top bar when recording)
            if recorder.isRecording && recorder.lowDiskSpaceWarning {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 12))
                    Text("Low Storage")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
                .padding(.top, 8)
            }

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

            // Session info card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)

                    Text("Study Session")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text(formattedDuration)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.accentColor)
                }

                HStack {
                    Text("\((recorder.recordingDuration / 3600).formattedDuration) of study time")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
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
                VStack(spacing: 12) {
                    // Top row: Retake and Save
                    HStack(spacing: 16) {
                        // Retake button
                        Button {
                            player?.pause()
                            player = nil
                            previewThumbnail = nil
                            voiceoverURL = nil
                            hasVoiceoverAdded = false
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
                                await saveVideo()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Save")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.accentColor)
                            .cornerRadius(16)
                        }
                    }

                    // Bottom row: Voiceover and Share
                    HStack(spacing: 16) {
                        // Voiceover button
                        Button {
                            startVoiceoverCountdown()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: hasVoiceoverAdded ? "arrow.counterclockwise" : "mic.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(hasVoiceoverAdded ? "Re-record" : "Voiceover")
                                    .font(.system(size: 17, weight: .semibold))
                                if hasVoiceoverAdded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(hasVoiceoverAdded ? Color.orange.opacity(0.8) : Color.orange)
                            .cornerRadius(16)
                        }

                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Share")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                        }
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

    var isLandscape: Bool {
        recorder.deviceOrientation == .landscapeLeft || recorder.deviceOrientation == .landscapeRight
    }

    var recordedInLandscape: Bool {
        recorder.recordingOrientation == .landscapeLeft || recorder.recordingOrientation == .landscapeRight
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
                // Check disk space before starting
                let (canStart, message) = recorder.canStartRecording()
                if canStart {
                    if let warningMessage = message {
                        // Show warning but allow recording
                        errorMessage = warningMessage
                    }
                    recorder.startRecording()
                } else {
                    // Can't start - show error
                    errorMessage = message ?? "Cannot start recording"
                }
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
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: uploadProgress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: uploadProgress)

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
                goalTodoId: goalTodoId,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath,
                durationMinutes: studyTimeMinutes
            )

            uploadProgress = 0.85

            // Attach video and mark goal todo as completed if provided (single todo mode)
            if let goalTodoId = goalTodoId {
                try? await ConvexService.shared.attachVideoToGoalTodo(
                    id: goalTodoId,
                    localVideoPath: localVideoPath,
                    localThumbnailPath: localThumbnailPath,
                    videoDurationMinutes: studyTimeMinutes
                )
                try? await ConvexService.shared.toggleGoalTodo(id: goalTodoId, isCompleted: true)
            }

            uploadProgress = 0.9

            // Attach video to all checked todos from session (multi-todo mode)
            if !checkedTodoIds.isEmpty {
                for todoId in checkedTodoIds {
                    try? await ConvexService.shared.attachVideoToGoalTodo(
                        id: todoId,
                        localVideoPath: localVideoPath,
                        localThumbnailPath: localThumbnailPath,
                        videoDurationMinutes: studyTimeMinutes
                    )
                    try? await ConvexService.shared.toggleGoalTodo(id: todoId, isCompleted: true)
                }
            }

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
    TimeLapseRecorderView(goalId: "123", goalTodoId: nil)
}
