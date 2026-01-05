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
    case iphoneMode = "iPhone"

    var captureInterval: TimeInterval {
        switch self {
        case .normal: return 0.0         // Capture every camera frame (true real-time ~30fps)
        case .timelapse: return 0.5      // 2 fps - 15x speedup
        case .ultraFast: return 2.0      // 0.5 fps - 60x speedup
        case .iphoneMode: return 0.5     // Initial interval (auto-adjusts over time)
        }
    }

    var rateLabel: String {
        switch self {
        case .normal: return "30 fps"
        case .timelapse: return "2 fps"
        case .ultraFast: return "0.5 fps"
        case .iphoneMode: return "Auto"
        }
    }

    var isDynamicInterval: Bool {
        return self == .iphoneMode
    }
}

struct TimeLapseRecorderView: View {
    let goalId: String
    let goalTodoId: String?
    let availableTodos: [GoalTodo]

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var recordingSession: RecordingSessionManager
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

    // Video notes state
    @State private var pendingNotes: String = ""
    @State private var showNotesSheet: Bool = false

    // Continue mode state
    @State private var isContinueMode = false
    @State private var existingVideoURL: URL?
    @State private var existingSpeedSegmentsJSON: String?
    @State private var existingDuration: TimeInterval = 0
    @State private var existingNotes: String?

    // Partner sharing state
    @State private var showShareWithPartners = false
    @State private var savedVideoPath: String?
    @State private var savedDurationMinutes: Double = 0
    @StateObject private var partnersViewModel = PartnersViewModel()

    // Privacy mode
    @StateObject private var privacyManager = PrivacyModeManager()

    // Track intentional dismissal vs app backgrounding
    @State private var isDismissing = false

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
                // Full screen camera preview (hidden in stealth mode)
                CameraPreview(session: recorder.captureSession)
                    .ignoresSafeArea()
                    .opacity(privacyManager.shouldHideControls && recorder.isRecording ? 0 : 1)

                // Camera overlay controls (hidden in privacy mode)
                if !privacyManager.shouldHideControls || !recorder.isRecording {
                    cameraOverlayControls
                }

                // Floating todo checklist (hidden in privacy mode)
                if !availableTodos.isEmpty && recorder.isRecording && !privacyManager.shouldHideControls {
                    todoChecklistOverlay
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
                // Set initial capture interval
                recorder.setCaptureInterval(
                    selectedSpeed.captureInterval,
                    rateName: selectedSpeed.rateLabel,
                    iphoneMode: selectedSpeed.isDynamicInterval
                )
            }
        }
        .onDisappear {
            // Only cleanup if intentionally dismissing (not just app backgrounding)
            guard isDismissing else { return }

            // Re-enable screen auto-lock
            UIApplication.shared.isIdleTimerDisabled = false

            recorder.cleanup()
            dismissAlarm()
            // Lock back to portrait when leaving
            OrientationManager.shared.lockToPortrait()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Restart camera session when returning from background
                // Recording continues without pausing
                if !recorder.captureSession.isRunning {
                    Task {
                        await recorder.setupCamera()
                    }
                }
            }
            // Note: We don't auto-pause on background anymore
            // iOS suspends AVCaptureSession automatically, but we keep the recording state active
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
                    todoTitle: nil
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

    // MARK: - Continue Recording

    private func startContinueFromPreview() {
        guard let videoURL = recorder.recordedVideoURL else { return }

        // Store current video as the one to continue from
        existingVideoURL = videoURL
        existingSpeedSegmentsJSON = isContinueMode ? recorder.getMergedSpeedSegmentsJSON() : recorder.getSpeedSegmentsJSON()
        existingDuration = isContinueMode ? recorder.getTotalRecordingDuration() : recorder.recordingDuration

        // Keep any notes we've added in this session
        if !pendingNotes.isEmpty {
            existingNotes = getMergedNotes()
            pendingNotes = ""  // Clear for new notes
        }

        isContinueMode = true

        // Clear preview state
        player?.pause()
        player = nil
        previewThumbnail = nil
        voiceoverURL = nil
        hasVoiceoverAdded = false

        // Start continue recording
        recorder.startContinueRecording(
            fromVideoURL: videoURL,
            previousSpeedSegmentsJSON: existingSpeedSegmentsJSON,
            previousDuration: existingDuration
        )

        print("🔄 Continue from preview: continuing from \(existingDuration)s video")
    }

    private func getMergedNotes() -> String? {
        guard isContinueMode else {
            return pendingNotes.isEmpty ? nil : pendingNotes
        }

        if let existing = existingNotes, !existing.isEmpty, !pendingNotes.isEmpty {
            return existing + "\n\n---\n\n" + pendingNotes
        } else if let existing = existingNotes, !existing.isEmpty {
            return existing
        } else if !pendingNotes.isEmpty {
            return pendingNotes
        }
        return nil
    }

    private func shareWithPartners(partnerIds: [String]) async {
        guard let videoURL = recorder.recordedVideoURL else {
            showShareWithPartners = false
            return
        }

        do {
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
                thumbnailR2Key: nil,
                durationMinutes: recorder.recordingDuration / 60.0,
                goalTitle: nil,
                todoTitle: nil,
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

    private var completedCount: Int {
        checkedTodoIds.count
    }

    private var totalCount: Int {
        availableTodos.count
    }

    var todoFloatingBadge: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showTodoList.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
        }
    }

    var todoListOverlay: some View {
        VStack(spacing: 0) {
            // Compact header
            HStack {
                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(completedCount == totalCount && totalCount > 0 ? .green : .white)

                Text("Tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTodoList = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Todo list - max 4 visible, scrollable
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(availableTodos) { todo in
                        Button {
                            toggleTodoCheck(todo)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: checkedTodoIds.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(checkedTodoIds.contains(todo.id) ? .green : .white.opacity(0.5))

                                Text(todo.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .strikethrough(checkedTodoIds.contains(todo.id))
                                    .opacity(checkedTodoIds.contains(todo.id) ? 0.5 : 1.0)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 4 * 36) // ~4 items visible
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }

    private func toggleTodoCheck(_ todo: GoalTodo) {
        if checkedTodoIds.contains(todo.id) {
            checkedTodoIds.remove(todo.id)
        } else {
            checkedTodoIds.insert(todo.id)
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    var todoChecklistOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    todoFloatingBadge

                    if showTodoList {
                        todoListOverlay
                            .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 110)

                Spacer()
            }

            Spacer()
        }
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

            Text("\(Int(recorder.compilationProgress * 100))%")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
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
                    isDismissing = true
                    recorder.cleanup()
                    recordingSession.endSession()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                }

                // Privacy mode toggle
                PrivacyModeToggle(privacyManager: privacyManager)

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
                    isDismissing = true
                    recorder.cleanup()
                    recordingSession.endSession()
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
                VStack(spacing: 16) {
                    // Icon action row
                    HStack(spacing: 0) {
                        // Retake
                        actionIconButton(
                            icon: "arrow.counterclockwise",
                            label: "Retake",
                            isActive: false
                        ) {
                            player?.pause()
                            player = nil
                            previewThumbnail = nil
                            voiceoverURL = nil
                            hasVoiceoverAdded = false
                            pendingNotes = ""
                            isContinueMode = false
                            recorder.clearFrames()
                        }

                        // Resume More
                        actionIconButton(
                            icon: "plus.circle",
                            label: "Resume",
                            isActive: false
                        ) {
                            startContinueFromPreview()
                        }

                        // Notes
                        actionIconButton(
                            icon: pendingNotes.isEmpty ? "note.text" : "note.text.badge.checkmark",
                            label: "Notes",
                            isActive: !pendingNotes.isEmpty
                        ) {
                            showNotesSheet = true
                        }

                        // Voiceover
                        actionIconButton(
                            icon: hasVoiceoverAdded ? "waveform" : "mic.fill",
                            label: hasVoiceoverAdded ? "Re-record" : "Voice",
                            isActive: hasVoiceoverAdded
                        ) {
                            startVoiceoverCountdown()
                        }

                        // Share
                        actionIconButton(
                            icon: "square.and.arrow.up",
                            label: "Share",
                            isActive: false
                        ) {
                            showShareSheet = true
                        }

                        // Partners (if available)
                        if !partnersViewModel.partners.isEmpty {
                            actionIconButton(
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

                    // Primary save button
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
    private func actionIconButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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
            // Use total duration for continue mode, otherwise just current recording
            let studyTimeMinutes = (isContinueMode ? recorder.getTotalRecordingDuration() : recorder.recordingDuration) / 60.0
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

            // Create study session with local path and notes (use merged notes for continue mode)
            let notesToSave = getMergedNotes()
            _ = try await ConvexService.shared.createStudySession(
                goalId: goalId,
                goalTodoId: goalTodoId,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath,
                durationMinutes: studyTimeMinutes,
                notes: notesToSave
            )

            uploadProgress = 0.85

            // Attach video and mark goal todo as completed if provided (single todo mode)
            if let goalTodoId = goalTodoId {
                try? await ConvexService.shared.attachVideoToGoalTodo(
                    id: goalTodoId,
                    localVideoPath: localVideoPath,
                    localThumbnailPath: localThumbnailPath,
                    videoDurationMinutes: studyTimeMinutes,
                    videoNotes: notesToSave
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
                        videoDurationMinutes: studyTimeMinutes,
                        videoNotes: notesToSave
                    )
                    try? await ConvexService.shared.toggleGoalTodo(id: todoId, isCompleted: true)
                }
            }

            uploadProgress = 1.0
            uploadSuccess = true

            // Clean up temp file
            try? FileManager.default.removeItem(at: videoURL)

            // Store for potential partner sharing
            savedVideoPath = localVideoPath
            savedDurationMinutes = studyTimeMinutes

            // Reset continue mode
            isContinueMode = false

            isDismissing = true
            recordingSession.endSession()

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
