//
//  CameraRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct CameraRecorderView: View {
    let goalId: String
    let goalTodoId: String?

    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: CameraRecorderViewModel
    @State private var previewThumbnail: UIImage?
    @State private var player: AVPlayer?

    // Track intentional dismissal vs app backgrounding
    @State private var isDismissing = false

    // Privacy mode
    @StateObject private var privacyManager = PrivacyModeManager()

    private let videoService = VideoService.shared

    init(goalId: String, goalTodoId: String?) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        _viewModel = StateObject(wrappedValue: CameraRecorderViewModel(goalId: goalId, goalTodoId: goalTodoId))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Camera preview or video preview
                    if viewModel.recordedVideoURL != nil {
                        videoPreviewView
                            .padding(.horizontal)
                    } else {
                        ZStack {
                            CameraPreview(session: viewModel.captureSession)
                                .frame(height: 600)
                                .cornerRadius(20)
                                .opacity(privacyManager.shouldHideControls && viewModel.isRecording ? 0 : 1)

                            // Camera flip button (shown when not recording, hidden in privacy mode)
                            if !viewModel.isRecording && !privacyManager.shouldHideControls {
                                VStack {
                                    HStack {
                                        // Privacy mode toggle
                                        PrivacyModeToggle(privacyManager: privacyManager)

                                        Spacer()

                                        Button {
                                            viewModel.switchCamera()
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

                            // Recording overlay (hidden in privacy mode)
                            if viewModel.isRecording && !privacyManager.shouldHideControls {
                                VStack {
                                    HStack {
                                        // Recording indicator
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 12, height: 12)
                                                .opacity(viewModel.recordingPulse ? 1.0 : 0.3)

                                            Text("REC")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .shadow(color: .black, radius: 2)
                                        }
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(8)

                                        Spacer()

                                        // Timer
                                        Text(viewModel.formattedDuration)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.black.opacity(0.5))
                                            .cornerRadius(8)
                                    }
                                    .padding()

                                    Spacer()
                                }
                            }

                            // MARK: - Privacy Mode Overlay

                            // Stealth stopwatch overlay (shows minimal timer on black screen)
                            if privacyManager.shouldHideControls && viewModel.isRecording {
                                StealthStopwatchView(
                                    recordingDuration: viewModel.recordingDuration,
                                    onDoubleTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            privacyManager.deactivate()
                                        }
                                    },
                                    onStopRecording: {
                                        viewModel.stopRecording()
                                    }
                                )
                                .frame(height: 600)
                                .cornerRadius(20)
                                .transition(.opacity)
                            }

                            // Privacy toggle always accessible during privacy mode
                            if privacyManager.shouldHideControls && viewModel.isRecording {
                                VStack {
                                    HStack {
                                        PrivacyModeToggle(privacyManager: privacyManager)
                                        Spacer()
                                    }
                                    .padding()
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    // Controls (hidden in privacy mode when recording)
                    if viewModel.isUploading {
                        uploadProgressView
                    } else if viewModel.recordedVideoURL != nil {
                        finishedRecordingButtons
                    } else if !privacyManager.shouldHideControls || !viewModel.isRecording {
                        recordingButton
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isDismissing = true
                        viewModel.cancelRecording()
                        dismiss()
                    }
                    .foregroundColor(Color.accentColor)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            // Prevent screen from turning off during recording
            UIApplication.shared.isIdleTimerDisabled = true
            viewModel.setupCamera()
        }
        .onDisappear {
            // Only cleanup if intentionally dismissing (not just app backgrounding)
            guard isDismissing else { return }

            // Re-enable screen auto-lock
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.cleanup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Restart camera session when returning from background
                // Recording continues without stopping
                if !viewModel.captureSession.isRunning {
                    viewModel.setupCamera()
                }
            }
            // Note: We don't auto-stop on background anymore
        }
        .onChange(of: viewModel.isRecording) { _, isRecording in
            // Activate/deactivate privacy mode when recording starts/stops
            if isRecording {
                privacyManager.onRecordingStarted()
            } else {
                privacyManager.onRecordingStopped()
            }
        }
    }

    var recordingButton: some View {
        HStack {
            Spacer()

            Button {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(viewModel.isRecording ? Color.red : Color.accentColor, lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.accentColor)
                        .frame(width: 80, height: 80)

                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }

            Spacer()
        }
    }

    var videoPreviewView: some View {
        ZStack {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 600)
                    .clipped()
                    .cornerRadius(20)
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .frame(height: 600)
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                            Text("Loading preview...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }

            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        guard let videoURL = viewModel.recordedVideoURL else { return }
        player = AVPlayer(url: videoURL)
    }

    var finishedRecordingButtons: some View {
        HStack(spacing: 40) {
            // Retake
            Button {
                player = nil
                previewThumbnail = nil
                viewModel.retakeRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                }
            }

            // Save
            Button {
                Task {
                    await viewModel.saveVideo()
                    if viewModel.uploadSuccess {
                        isDismissing = true
                        dismiss()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 70, height: 70)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)

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
                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.uploadProgress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)

                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Saving...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
    }
}

// Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Update orientation when the view updates
        uiView.updateOrientation()
    }
}

// Custom UIView that uses AVCaptureVideoPreviewLayer as its backing layer
// This ensures the layer automatically resizes with the view during rotation
class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        // Observe device orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func orientationDidChange() {
        updateOrientation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Called when view's bounds change (including rotation)
        updateOrientation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Update orientation when view is added to window hierarchy
        // Use async dispatch to ensure preview layer connection is ready
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.updateOrientation()
            }
        }
    }

    func updateOrientation() {
        guard let connection = previewLayer.connection,
              connection.isVideoOrientationSupported else { return }

        let deviceOrientation = UIDevice.current.orientation

        // Check if device orientation is valid for video
        if deviceOrientation == .portrait || deviceOrientation == .landscapeLeft ||
           deviceOrientation == .landscapeRight || deviceOrientation == .portraitUpsideDown {
            switch deviceOrientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .landscapeLeft:
                connection.videoOrientation = .landscapeRight
            case .landscapeRight:
                connection.videoOrientation = .landscapeLeft
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                break
            }
        } else {
            // Fallback: when device orientation is unknown/faceUp/faceDown,
            // use the interface orientation from the window scene
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let interfaceOrientation = windowScene.interfaceOrientation
                switch interfaceOrientation {
                case .portrait, .portraitUpsideDown:
                    connection.videoOrientation = .portrait
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeLeft
                case .landscapeRight:
                    connection.videoOrientation = .landscapeRight
                default:
                    break
                }
            }
        }
    }
}

// ViewModel for CameraRecorderView
@MainActor
class CameraRecorderViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordedVideoURL: URL?
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadSuccess = false
    @Published var errorMessage: String?
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingPulse = false
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private let goalId: String
    private let goalTodoId: String?
    private let videoService = VideoService.shared
    private var recordingTimer: Timer?
    private var pulseTimer: Timer?

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init(goalId: String, goalTodoId: String?) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        super.init()
    }

    func setupCamera() {
        Task {
            await requestCameraPermission()
            await configureCaptureSession()
        }
    }

    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    private func configureCaptureSession() async {
        captureSession.beginConfiguration()

        // Set session preset for video recording
        captureSession.sessionPreset = .high

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            await MainActor.run {
                errorMessage = "Failed to access camera"
            }
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(videoInput)
        currentVideoInput = videoInput

        // Add movie file output
        let movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            videoOutput = movieOutput
        }

        captureSession.commitConfiguration()

        // Start session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func startRecording() {
        guard let videoOutput = videoOutput else {
            errorMessage = "Camera not ready"
            return
        }

        isRecording = true
        recordingDuration = 0

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordingDuration += 1
            }
        }

        // Start pulse animation timer
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.recordingPulse.toggle()
            }
        }
    }

    func stopRecording() {
        videoOutput?.stopRecording()
        recordingTimer?.invalidate()
        pulseTimer?.invalidate()
        isRecording = false
    }

    func retakeRecording() {
        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedVideoURL = nil
        recordingDuration = 0
    }

    func saveVideo() async {
        guard let videoURL = recordedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            // Get video duration
            let durationMinutes = recordingDuration / 60.0
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
                durationMinutes: durationMinutes
            )

            // Mark goal todo as completed if provided
            if let goalTodoId = goalTodoId {
                try? await ConvexService.shared.toggleGoalTodo(id: goalTodoId, isCompleted: true)
            }

            uploadProgress = 1.0
            uploadSuccess = true

            // Clean up temp file
            try? FileManager.default.removeItem(at: videoURL)

        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0
        }
    }

    func cancelRecording() {
        if isRecording {
            stopRecording()
        }
        recordingTimer?.invalidate()
        pulseTimer?.invalidate()
    }

    func cleanup() {
        cancelRecording()
        captureSession.stopRunning()

        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func switchCamera() {
        guard !isRecording else {
            errorMessage = "Cannot switch camera while recording"
            return
        }

        guard let currentInput = currentVideoInput else {
            errorMessage = "No camera input found"
            return
        }

        // Determine new camera position
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front

        // Get new camera device
        guard let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newVideoInput = try? AVCaptureDeviceInput(device: newVideoDevice) else {
            errorMessage = "Failed to access \(newPosition == .front ? "front" : "back") camera"
            return
        }

        // Configure session with new input
        captureSession.beginConfiguration()

        // Remove old input
        captureSession.removeInput(currentInput)

        // Add new input
        if captureSession.canAddInput(newVideoInput) {
            captureSession.addInput(newVideoInput)
            currentVideoInput = newVideoInput
            currentCameraPosition = newPosition
        } else {
            // If we can't add new input, restore the old one
            captureSession.addInput(currentInput)
            errorMessage = "Failed to switch camera"
        }

        captureSession.commitConfiguration()
    }
}

// AVCaptureFileOutputRecordingDelegate
extension CameraRecorderViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
            } else {
                self.recordedVideoURL = outputFileURL
            }
        }
    }
}

#Preview {
    CameraRecorderView(goalId: "123", goalTodoId: nil)
}
