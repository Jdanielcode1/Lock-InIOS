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
    let subtaskId: String?

    @Environment(\.dismiss) var dismiss
    @StateObject private var recorder: TimeLapseRecorder
    @StateObject private var todoViewModel = TodoViewModel()
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    @State private var previewThumbnail: UIImage?
    @State private var player: AVPlayer?
    @State private var selectedSpeed: TimelapseSpeed = .timelapse

    // Todo tracking state
    @State private var showTodoSelection = true
    @State private var selectedTodoIds: Set<String> = []
    @State private var checkedTodoIds: Set<String> = []
    @State private var showTodoOverlay = false

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

    private let videoService = VideoService.shared

    // Computed properties for todos
    private var selectedTodos: [TodoItem] {
        todoViewModel.todos.filter { selectedTodoIds.contains($0.id) }
    }

    private var completedTodoCount: Int {
        checkedTodoIds.count
    }

    private var totalTodoCount: Int {
        selectedTodoIds.count
    }

    init(goalId: String, subtaskId: String?) {
        self.goalId = goalId
        self.subtaskId = subtaskId
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

                // Todo list overlay (when expanded)
                if showTodoOverlay && totalTodoCount > 0 {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showTodoOverlay = false
                            }
                        }

                    todoListOverlay
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // Alarm overlay
                if showAlarmOverlay {
                    alarmOverlay
                }
            }
        }
        .sheet(isPresented: $showTodoSelection) {
            TodoSelectionSheet(
                selectedTodoIds: $selectedTodoIds,
                onStart: {
                    showTodoSelection = false
                },
                onSkip: {
                    selectedTodoIds.removeAll()
                    showTodoSelection = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Allow landscape orientation in recorder
            OrientationManager.shared.allowAllOrientations()

            Task {
                await recorder.setupCamera()
                // Set initial capture interval
                recorder.setCaptureInterval(selectedSpeed.captureInterval, rateName: selectedSpeed.rateLabel)
            }
        }
        .onDisappear {
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
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
                            colors: [AppTheme.actionBlue, AppTheme.actionBlue.opacity(0.3)],
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Compiling \(recorder.frameCount) frames...")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
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

                // Todo badge (only show if todos selected)
                if totalTodoCount > 0 {
                    todoFloatingBadge
                }

                Spacer()

                // Audio toggle button (only enabled in Normal mode)
                Button {
                    recorder.toggleAudio()
                } label: {
                    Image(systemName: recorder.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(audioButtonColor)
                        .padding(12)
                        .background(Color.black.opacity(recorder.isAudioAllowed ? 0.5 : 0.2))
                        .clipShape(Circle())
                }
                .disabled(!recorder.isAudioAllowed && !recorder.isAudioEnabled)
                .opacity(recorder.isAudioAllowed || recorder.isAudioEnabled ? 1.0 : 0.5)

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
                            .font(.system(size: 17, weight: .bold, design: .rounded))
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
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("Study Session")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text(formattedDuration)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.actionBlue)
                }

                HStack {
                    Text(String(format: "%.1f hours of study time", recorder.recordingDuration / 3600))
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
            if isUploading {
                uploadProgressView
                    .padding(.bottom, 40)
            } else {
                HStack(spacing: 20) {
                    // Retake button
                    Button {
                        player?.pause()
                        player = nil
                        previewThumbnail = nil
                        checkedTodoIds.removeAll()
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
                        .background(AppTheme.primaryGradient)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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

    var audioButtonColor: Color {
        if recorder.isAudioEnabled {
            return .white
        } else if recorder.isAudioAllowed {
            return .red
        } else {
            return .gray // Disabled state for timelapse modes
        }
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
                    .foregroundColor(countdownEnabled ? AppTheme.actionBlue : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(countdownEnabled ? AppTheme.actionBlue.opacity(0.2) : Color.black.opacity(0.5))
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

    // MARK: - Todo Badge and Overlay

    var todoFloatingBadge: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showTodoOverlay.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: completedTodoCount == totalTodoCount ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(completedTodoCount)/\(totalTodoCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(completedTodoCount == totalTodoCount ? .green : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
        }
    }

    var todoListOverlay: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Tasks")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTodoOverlay = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.2))

            // Todo list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(selectedTodos) { todo in
                        Button {
                            toggleTodoCheck(todo)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checkedTodoIds.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(checkedTodoIds.contains(todo.id) ? .green : .white.opacity(0.6))

                                Text(todo.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .strikethrough(checkedTodoIds.contains(todo.id))
                                    .opacity(checkedTodoIds.contains(todo.id) ? 0.6 : 1.0)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 250)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial.opacity(0.95))
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private func toggleTodoCheck(_ todo: TodoItem) {
        if checkedTodoIds.contains(todo.id) {
            checkedTodoIds.remove(todo.id)
        } else {
            checkedTodoIds.insert(todo.id)
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

            uploadProgress = 0.9

            // Mark checked todos as completed
            for todoId in checkedTodoIds {
                try? await ConvexService.shared.toggleTodo(id: todoId, isCompleted: true)
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
    TimeLapseRecorderView(goalId: "123", subtaskId: nil)
}
