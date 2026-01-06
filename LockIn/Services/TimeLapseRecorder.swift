//
//  TimeLapseRecorder.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import AVFoundation
import UIKit

// MARK: - Segment Tracking Structs

/// Tracks a period where the capture speed was constant
struct SpeedSegment: Codable {
    let startFrameIndex: Int      // First frame index in this segment
    var endFrameIndex: Int        // Last frame index (exclusive)
    let startRealTime: TimeInterval  // Real time when segment started (excluding pauses)
    var endRealTime: TimeInterval    // Real time when segment ended
    let frameInterval: TimeInterval  // Capture interval during this segment

    /// Calculate the speed multiplier for this segment (playback speed vs real time)
    var speedMultiplier: Double {
        // Normal mode (frameInterval <= 0) = 1x speed
        // Timelapse: playback at 30fps, captured at 1/frameInterval fps
        // speedMultiplier = 30 * frameInterval (e.g., 0.5s interval = 15x speed)
        return frameInterval <= 0 ? 1.0 : 30.0 * frameInterval
    }
}

/// Tracks a period where audio was being recorded
struct AudioSegment {
    let startRealTime: TimeInterval  // When audio started (relative to recording start)
    var endRealTime: TimeInterval    // When audio stopped
    let audioFileURL: URL            // The audio file for this segment
    let frameInterval: TimeInterval  // The capture interval when this segment started (for speedup calculation)
    let startFrameIndex: Int         // The frame index when audio started (for video position)
}

/// Maps a video frame to its real-time capture moment
struct FrameTimestamp {
    let frameIndex: Int
    let realTimeOffset: TimeInterval  // Seconds since recording started (excluding pauses)
}

@MainActor
class TimeLapseRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var isCompilingVideo = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var frameCount: Int = 0
    @Published var recordedVideoURL: URL?
    @Published var currentCaptureRate: String = "2 fps"
    @Published var deviceOrientation: UIDeviceOrientation = .portrait
    @Published var isAudioEnabled = false // Audio recording toggle (disabled by default)

    // Compilation progress (0.0 to 1.0)
    @Published var compilationProgress: Double = 0

    // Disk space warnings
    @Published var lowDiskSpaceWarning: Bool = false
    @Published var diskSpaceError: String?

    // Zoom level (0.5 = ultra-wide, 1.0 = wide, 2.0+ = telephoto)
    @Published var currentZoomLevel: CGFloat = 1.0  // 0.5 = ultra-wide, 1.0 = normal
    @Published var hasUltraWide: Bool = false  // Whether 0.5x is available

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var isUsingVirtualDevice: Bool = false  // True if using triple/dual camera

    // Audio recording
    private var audioRecorder: AVAudioRecorder?
    private var currentAudioFileURL: URL?

    // Segment tracking for proper sync
    private var speedSegments: [SpeedSegment] = []
    private var audioSegments: [AudioSegment] = []
    private var frameTimestamps: [FrameTimestamp] = []

    var capturedFrameURLs: [URL] = []
    private var frameStorageDirectory: URL?
    private var startTime: Date?
    private var lastCaptureTime: Date?
    private var frameInterval: TimeInterval = 0.5 // Default: timelapse speed (2 fps)
    private var manualSpeedOverride: Bool = false // User manually set speed
    private let outputFPS: Int32 = 30 // Playback at 30 fps
    // Frame-based limits (more meaningful than time-based)
    private let warningFrameCount = 50_000       // Show warning to user
    private let softLimitFrameCount = 100_000    // Strong warning (~10GB storage, long compile)
    private let hardLimitFrameCount = 200_000    // Force stop to prevent crashes/issues

    // Published warning state for UI
    @Published var frameCountWarning: FrameCountWarning = .none

    enum FrameCountWarning {
        case none
        case approaching      // 50k+ frames
        case high             // 100k+ frames
    }

    // Disk space constants
    private let minRequiredDiskSpaceMB: Int64 = 500 // 500 MB minimum
    private let estimatedFrameSizeKB: Int64 = 100 // ~100 KB per JPEG frame
    private let lowDiskSpaceThresholdMB: Int64 = 1000 // Warn at 1 GB remaining

    // iPhone Mode - auto-adjusting interval thresholds (recording duration -> capture interval)
    // Apple's algorithm: double interval AND delete every other frame to keep video 20-40 sec
    private static let iphoneModeIntervals: [(maxMinutes: Double, interval: TimeInterval, rateLabel: String)] = [
        (10, 0.5, "2 fps"),      // 0-10 min: 0.5s interval (2 fps), 15x speedup
        (20, 1.0, "1 fps"),      // 10-20 min: 1s interval (1 fps), 30x speedup
        (40, 2.0, "0.5 fps"),    // 20-40 min: 2s interval (0.5 fps), 60x speedup
        (80, 4.0, "0.25 fps"),   // 40-80 min: 4s interval (0.25 fps), 120x speedup
        (Double.infinity, 8.0, "0.125 fps")  // 80+ min: 8s interval (0.125 fps), 240x speedup
    ]
    private var isIphoneMode: Bool = false
    private var iphoneModeCurrentTier: Int = 0  // Track which tier we're on to detect changes

    // For iPhone mode: track total real recording time (since frame deletion changes frame-based calculations)
    @Published var iphoneModeRealDuration: TimeInterval = 0

    // Background task for compilation
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // Continue mode - for resuming previous recordings
    private var continueFromVideoURL: URL?
    private var previousSpeedSegments: [SpeedSegment] = []
    private var previousFrameCount: Int = 0
    private var previousDuration: TimeInterval = 0
    @Published var isContinueMode: Bool = false

    private var recordingTimer: Timer?
    private let videoQueue = DispatchQueue(label: "com.lockin.timelapse.video")
    @Published var recordingOrientation: UIDeviceOrientation = .portrait

    // Pause tracking
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    // Track current audio segment start time, mode, and frame position
    private var currentAudioStartTime: TimeInterval = 0
    private var currentAudioFrameInterval: TimeInterval = 0.5  // The frame interval when audio started
    private var currentAudioStartFrameIndex: Int = 0           // The frame index when audio started

    // MARK: - Accurate Time Calculation

    /// Returns the current recording time (excluding pauses) using actual wall clock
    /// This is more accurate than the timer-updated recordingDuration which can be up to 0.1s stale
    private func calculateActualRealTime() -> TimeInterval {
        guard let start = startTime else { return 0 }
        let now = Date()
        var totalPaused = pausedDuration
        if isPaused, let pauseStart = pauseStartTime {
            totalPaused += now.timeIntervalSince(pauseStart)
        }
        return now.timeIntervalSince(start) - totalPaused
    }

    // MARK: - Disk Space Management

    /// Returns available disk space in bytes
    func getAvailableDiskSpace() -> Int64 {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                return freeSpace
            }
        } catch {
            print("❌ Failed to get disk space: \(error)")
        }
        return 0
    }

    /// Returns available disk space in MB
    func getAvailableDiskSpaceMB() -> Int64 {
        return getAvailableDiskSpace() / (1024 * 1024)
    }

    /// Check if there's enough disk space to start recording
    func canStartRecording() -> (canStart: Bool, message: String?) {
        let availableMB = getAvailableDiskSpaceMB()

        if availableMB < minRequiredDiskSpaceMB {
            return (false, "Not enough storage space. Need at least \(minRequiredDiskSpaceMB) MB free, but only \(availableMB) MB available.")
        }

        if availableMB < lowDiskSpaceThresholdMB {
            lowDiskSpaceWarning = true
            return (true, "Low storage space (\(availableMB) MB). Recording may stop early.")
        }

        lowDiskSpaceWarning = false
        return (true, nil)
    }

    /// Check disk space during recording and stop if critically low
    private func checkDiskSpaceDuringRecording() {
        let availableMB = getAvailableDiskSpaceMB()

        if availableMB < minRequiredDiskSpaceMB / 2 {
            // Critical - stop recording immediately
            print("⚠️ Critical disk space! Stopping recording...")
            diskSpaceError = "Recording stopped: Storage full"
            stopRecording()
            return
        }

        if availableMB < lowDiskSpaceThresholdMB && !lowDiskSpaceWarning {
            lowDiskSpaceWarning = true
            print("⚠️ Low disk space warning: \(availableMB) MB remaining")
        }
    }

    /// Check frame count and update warning state, returns true if should stop
    private func checkFrameCountLimits() -> Bool {
        if frameCount >= hardLimitFrameCount {
            // Hard stop - too many frames could crash during compilation
            print("🛑 Hard frame limit reached (\(frameCount) frames). Stopping to prevent issues.")
            return true
        }

        // Update warning state for UI
        if frameCount >= softLimitFrameCount {
            if frameCountWarning != .high {
                frameCountWarning = .high
                print("⚠️ High frame count warning: \(frameCount) frames (~\(frameCount / 10)MB)")
            }
        } else if frameCount >= warningFrameCount {
            if frameCountWarning != .approaching {
                frameCountWarning = .approaching
                print("⚠️ Frame count warning: \(frameCount) frames")
            }
        }

        return false
    }

    /// Estimate remaining recording capacity based on storage
    func getEstimatedRemainingMinutes() -> Int? {
        let availableMB = getAvailableDiskSpaceMB()
        let estimatedFramesRemaining = (availableMB * 1024) / estimatedFrameSizeKB

        // Estimate based on current capture rate
        let framesPerMinute: Double
        if frameInterval <= 0 {
            framesPerMinute = 30 * 60  // Normal mode: 30fps
        } else {
            framesPerMinute = 60 / frameInterval  // Timelapse: depends on interval
        }

        return Int(Double(estimatedFramesRemaining) / framesPerMinute)
    }

    /// Get the speed segments for this recording (for accurate stopwatch in recaps)
    func getSpeedSegments() -> [SpeedSegment] {
        return speedSegments
    }

    /// Export speed segments as JSON string for storage
    func getSpeedSegmentsJSON() -> String? {
        guard !speedSegments.isEmpty else { return nil }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(speedSegments),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return nil
    }

    /// Parse speed segments from JSON string
    static func parseSpeedSegments(from json: String?) -> [SpeedSegment]? {
        guard let json = json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([SpeedSegment].self, from: data)
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VideoCompilation") { [weak self] in
            // Clean up if we run out of time
            print("⚠️ Background task expired")
            self?.endBackgroundTask()
        }
        print("📱 Started background task for compilation")
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("📱 Ended background task")
        }
    }

    // MARK: - Pause/Resume Recording

    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()

        // Pause audio recording
        audioRecorder?.pause()

        print("⏸️ Recording paused")
    }

    func resumeRecording() {
        guard isRecording && isPaused else { return }

        // Calculate how long we were paused
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        isPaused = false

        // Resume audio recording
        audioRecorder?.record()

        print("▶️ Recording resumed")
    }

    // Allow external control of capture interval
    func setCaptureInterval(_ interval: TimeInterval, rateName: String, iphoneMode: Bool = false) {
        let isNormalMode = interval <= 0
        let wasNormalMode = frameInterval <= 0

        // Track if iPhone Mode is active (for auto-adjusting intervals)
        self.isIphoneMode = iphoneMode

        // If recording, close current speed segment and start new one
        if isRecording {
            // Use actual time for accurate segment boundaries
            let actualTime = calculateActualRealTime()
            closeCurrentSpeedSegment(at: actualTime)

            // AUDIO ONLY WORKS IN NORMAL MODE
            // If switching FROM Normal TO Timelapse/UltraFast: stop audio recording
            if wasNormalMode && !isNormalMode && isAudioEnabled {
                print("🎤 Switching to timelapse mode - stopping audio recording")
                if currentAudioFileURL != nil {
                    closeCurrentAudioSegment(at: actualTime)
                }
                isAudioEnabled = false
                print("🎤 Audio disabled (not supported in timelapse modes)")
            }

            // Start new speed segment
            let newSegment = SpeedSegment(
                startFrameIndex: frameCount,
                endFrameIndex: frameCount,  // Will be updated as frames are captured
                startRealTime: actualTime,
                endRealTime: actualTime,
                frameInterval: interval
            )
            speedSegments.append(newSegment)
            print("📸 Speed changed at frame \(frameCount), real-time \(actualTime)s")
        }

        frameInterval = interval
        currentCaptureRate = rateName
        manualSpeedOverride = !iphoneMode  // Only set override for manual selections
        print("📸 Capture rate set to \(rateName) (interval: \(interval)s, iphoneMode: \(iphoneMode))")
    }

    /// Check if audio recording is allowed (only in Normal mode)
    var isAudioAllowed: Bool {
        return frameInterval <= 0
    }

    // Close the current speed segment
    private func closeCurrentSpeedSegment(at endTime: TimeInterval? = nil) {
        guard !speedSegments.isEmpty else { return }
        let actualEndTime = endTime ?? calculateActualRealTime()
        speedSegments[speedSegments.count - 1].endFrameIndex = frameCount
        speedSegments[speedSegments.count - 1].endRealTime = actualEndTime
    }

    // Toggle audio recording on/off (can be called during recording)
    // NOTE: Audio is only allowed in Normal mode (frameInterval <= 0)
    func toggleAudio() {
        // Prevent enabling audio in timelapse modes
        if !isAudioEnabled && !isAudioAllowed {
            print("🎤 Cannot enable audio in timelapse mode")
            return
        }

        isAudioEnabled.toggle()

        if isRecording {
            // Use actual time for accurate audio segment boundaries
            let actualTime = calculateActualRealTime()

            if isAudioEnabled {
                // Start new audio segment - record current frame interval and position for sync
                currentAudioStartTime = actualTime
                currentAudioFrameInterval = frameInterval
                currentAudioStartFrameIndex = frameCount
                startAudioRecording()
                print("🎤 Audio enabled at frame \(frameCount), real-time \(currentAudioStartTime)s, frameInterval: \(frameInterval)s")
            } else {
                // Close current audio segment with accurate time
                closeCurrentAudioSegment(at: actualTime)
                print("🎤 Audio disabled at real-time offset: \(actualTime)s")
            }
        }

        print("🎤 Audio \(isAudioEnabled ? "enabled" : "disabled")")
    }

    // Close the current audio segment and save it
    // Uses provided endTime for accuracy (actual wall clock time, not timer value)
    private func closeCurrentAudioSegment(at endTime: TimeInterval? = nil) {
        guard let audioURL = currentAudioFileURL else { return }

        audioRecorder?.stop()
        audioRecorder = nil

        // Use provided time or calculate actual time
        let actualEndTime = endTime ?? calculateActualRealTime()

        // Create segment record with the frame interval and position for sync
        let segment = AudioSegment(
            startRealTime: currentAudioStartTime,
            endRealTime: actualEndTime,
            audioFileURL: audioURL,
            frameInterval: currentAudioFrameInterval,
            startFrameIndex: currentAudioStartFrameIndex
        )
        audioSegments.append(segment)

        print("📝 Saved audio segment: frame \(segment.startFrameIndex), time \(segment.startRealTime)s - \(segment.endRealTime)s, frameInterval: \(segment.frameInterval)s")

        currentAudioFileURL = nil
    }

    func setupCamera() async {
        await requestCameraPermission()
        await requestMicrophonePermission()
        await configureCaptureSession()
        startOrientationObserver()
    }

    private func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    private func startAudioRecording() {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            currentAudioFileURL = audioURL
            print("🎙️ Started audio recording: \(audioURL.lastPathComponent)")
        } catch {
            print("❌ Failed to start audio recording: \(error)")
        }
    }

    private func stopAudioRecording(at endTime: TimeInterval? = nil) {
        // Close current audio segment if recording
        if currentAudioFileURL != nil {
            closeCurrentAudioSegment(at: endTime)
        }
        print("🎙️ Stopped audio recording")
    }

    private func startOrientationObserver() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        updateOrientation()
    }

    @objc private func orientationChanged() {
        updateOrientation()
    }

    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        // Only update for valid video orientations
        if orientation == .portrait || orientation == .landscapeLeft || orientation == .landscapeRight {
            deviceOrientation = orientation
        } else {
            // Fallback: when device orientation is unknown/faceUp/faceDown,
            // use the interface orientation from the window scene
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let interfaceOrientation = windowScene.interfaceOrientation
                switch interfaceOrientation {
                case .portrait, .portraitUpsideDown:
                    deviceOrientation = .portrait
                case .landscapeLeft:
                    // Interface landscapeLeft = device landscapeRight
                    deviceOrientation = .landscapeRight
                case .landscapeRight:
                    // Interface landscapeRight = device landscapeLeft
                    deviceOrientation = .landscapeLeft
                default:
                    break // Keep existing orientation
                }
            }
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

        captureSession.sessionPreset = .high

        // Try to get a virtual device for seamless zoom (back camera only)
        // Virtual devices allow smooth zoom between 0.5x and 1x
        var videoDevice: AVCaptureDevice?

        if currentCameraPosition == .back {
            // Try triple camera first (iPhone Pro models)
            videoDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)

            // Fall back to dual wide camera (iPhone 11+)
            if videoDevice == nil {
                videoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            }

            // Check if we got a virtual device with ultra-wide
            if let device = videoDevice {
                hasUltraWide = true
                isUsingVirtualDevice = true
                currentZoomLevel = 1.0
                // Set initial zoom to 2.0 (which is 1x on virtual device)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = 2.0  // 2.0 = wide angle (1x)
                    device.unlockForConfiguration()
                } catch {
                    print("❌ Failed to set initial zoom: \(error)")
                }
            }
        }

        // Fall back to standard wide angle camera
        if videoDevice == nil {
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition)
            hasUltraWide = false
            isUsingVirtualDevice = false
            currentZoomLevel = 1.0
        }

        guard let device = videoDevice,
              let videoInput = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(videoInput)
        currentVideoInput = videoInput

        print("📷 Camera: \(device.deviceType), hasUltraWide: \(hasUltraWide)")

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        }

        captureSession.commitConfiguration()

        // Start session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func startRecording() {
        isRecording = true
        isPaused = false
        capturedFrameURLs.removeAll()
        frameCount = 0
        recordingDuration = 0
        pausedDuration = 0
        pauseStartTime = nil
        startTime = Date()
        lastCaptureTime = nil
        recordedVideoURL = nil  // Clear so UI shows camera preview

        // Reset iPhone mode state
        iphoneModeCurrentTier = 0
        iphoneModeRealDuration = 0

        // Reset segment tracking
        speedSegments.removeAll()
        audioSegments.removeAll()
        frameTimestamps.removeAll()

        // Initialize first speed segment
        let initialSegment = SpeedSegment(
            startFrameIndex: 0,
            endFrameIndex: 0,
            startRealTime: 0,
            endRealTime: 0,
            frameInterval: frameInterval
        )
        speedSegments.append(initialSegment)

        // Force update orientation before capturing (handles initial landscape case)
        updateOrientation()

        // Capture the current orientation at the start of recording
        recordingOrientation = deviceOrientation

        // Create temporary directory for frame storage
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        frameStorageDirectory = tempDir

        print("📁 Created frame storage directory: \(tempDir.path)")

        // Start audio recording if enabled
        if isAudioEnabled {
            currentAudioStartTime = 0
            currentAudioFrameInterval = frameInterval  // Record the initial frame interval
            currentAudioStartFrameIndex = 0            // Starting from frame 0
            startAudioRecording()
        }

        // Start timer to update duration and frame interval
        var diskCheckCounter = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }

                // Calculate duration excluding paused time
                var totalPaused = self.pausedDuration
                if self.isPaused, let pauseStart = self.pauseStartTime {
                    totalPaused += Date().timeIntervalSince(pauseStart)
                }
                self.recordingDuration = Date().timeIntervalSince(start) - totalPaused

                // Track real duration for iPhone mode (used for stopwatch display)
                if self.isIphoneMode {
                    self.iphoneModeRealDuration = self.recordingDuration
                }

                self.updateFrameInterval()

                // Check disk space and frame count every 10 seconds (100 timer ticks)
                diskCheckCounter += 1
                if diskCheckCounter >= 100 {
                    diskCheckCounter = 0
                    self.checkDiskSpaceDuringRecording()

                    // Check frame count limits (only stop at hard limit)
                    if self.checkFrameCountLimits() {
                        self.stopRecording()
                    }
                }
            }
        }

        print("🎬 Started recording at \(currentCaptureRate) (no time limit, storage-based)")
    }

    /// Start recording in continue mode - will concatenate with existing video
    func startContinueRecording(
        fromVideoURL: URL,
        previousSpeedSegmentsJSON: String?,
        previousDuration: TimeInterval
    ) {
        // Parse previous speed segments
        if let json = previousSpeedSegmentsJSON {
            previousSpeedSegments = Self.parseSpeedSegments(from: json) ?? []
            previousFrameCount = previousSpeedSegments.last?.endFrameIndex ?? 0
        } else {
            previousSpeedSegments = []
            previousFrameCount = 0
        }

        self.continueFromVideoURL = fromVideoURL
        self.previousDuration = previousDuration
        self.isContinueMode = true

        print("🔄 Continue mode: from \(fromVideoURL.lastPathComponent), previous duration: \(previousDuration)s, previous frames: \(previousFrameCount)")

        // Start normal recording - concatenation happens on stop
        startRecording()
    }

    /// Reset continue mode state
    private func resetContinueMode() {
        continueFromVideoURL = nil
        previousSpeedSegments = []
        previousFrameCount = 0
        previousDuration = 0
        isContinueMode = false
    }

    private func updateFrameInterval() {
        // Only auto-adjust for iPhone Mode
        guard isIphoneMode else { return }

        let recordingMinutes = recordingDuration / 60.0

        // Find the appropriate tier based on recording duration
        var newTier = 0
        for (index, tier) in Self.iphoneModeIntervals.enumerated() {
            if recordingMinutes < tier.maxMinutes {
                newTier = index
                break
            }
        }

        // Check if we've moved to a new tier (interval needs to double)
        if newTier > iphoneModeCurrentTier {
            let tier = Self.iphoneModeIntervals[newTier]
            let previousTier = Self.iphoneModeIntervals[iphoneModeCurrentTier]

            print("📱 iPhone Mode: Tier change \(iphoneModeCurrentTier) → \(newTier) at \(String(format: "%.1f", recordingMinutes)) min")
            print("   Interval: \(previousTier.interval)s → \(tier.interval)s")
            print("   Frames before deletion: \(frameCount)")

            // Apple's algorithm: delete every other frame when interval doubles
            deleteEveryOtherFrame()

            print("   Frames after deletion: \(frameCount)")

            // Update to new interval
            frameInterval = tier.interval
            currentCaptureRate = tier.rateLabel
            iphoneModeCurrentTier = newTier

            // For iPhone mode, we use a simplified single-segment approach
            // since all frames now effectively represent the new interval
            speedSegments.removeAll()
            let actualTime = calculateActualRealTime()
            let newSegment = SpeedSegment(
                startFrameIndex: 0,
                endFrameIndex: frameCount,
                startRealTime: 0,
                endRealTime: actualTime,
                frameInterval: tier.interval
            )
            speedSegments.append(newSegment)

            print("📱 iPhone Mode: Now at \(tier.rateLabel), \(frameCount) frames")
        }
    }

    /// Delete every other frame (Apple's timelapse algorithm)
    /// This keeps the frame count bounded so final video stays 20-40 seconds
    private func deleteEveryOtherFrame() {
        guard frameCount > 1 else { return }

        var newFrameURLs: [URL] = []
        var newFrameTimestamps: [FrameTimestamp] = []

        // Keep every other frame (indices 0, 2, 4, 6, ...)
        for (index, url) in capturedFrameURLs.enumerated() {
            if index % 2 == 0 {
                // Keep this frame
                newFrameURLs.append(url)

                // Update timestamp with new index
                if index < frameTimestamps.count {
                    let oldTimestamp = frameTimestamps[index]
                    newFrameTimestamps.append(FrameTimestamp(
                        frameIndex: newFrameURLs.count - 1,
                        realTimeOffset: oldTimestamp.realTimeOffset
                    ))
                }
            } else {
                // Delete this frame file
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Rename remaining files to have sequential indices (optional but cleaner)
        // Skip this for performance - the indices in the array are what matter

        capturedFrameURLs = newFrameURLs
        frameTimestamps = newFrameTimestamps
        frameCount = capturedFrameURLs.count

        print("🗑️ Deleted \(capturedFrameURLs.count) frames, \(frameCount) remaining")
    }

    func stopRecording() {
        // Capture actual time before stopping timer
        let finalTime = calculateActualRealTime()

        isRecording = false
        isPaused = false
        isIphoneMode = false  // Reset iPhone Mode state
        frameCountWarning = .none  // Reset warning state
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Close current speed segment with actual time
        closeCurrentSpeedSegment(at: finalTime)

        // Stop audio recording (this closes the current audio segment with actual time)
        stopAudioRecording(at: finalTime)

        print("⏹️ Stopped timelapse recording. Captured \(frameCount) frames over \(finalTime) seconds")
        print("📊 Speed segments: \(speedSegments.count), Audio segments: \(audioSegments.count)")

        // Debug: Print segment details
        for (i, seg) in speedSegments.enumerated() {
            print("  Speed[\(i)]: frames \(seg.startFrameIndex)-\(seg.endFrameIndex), time \(seg.startRealTime)-\(seg.endRealTime)s, interval \(seg.frameInterval)s")
        }
        for (i, seg) in audioSegments.enumerated() {
            print("  Audio[\(i)]: frame \(seg.startFrameIndex), time \(seg.startRealTime)-\(seg.endRealTime)s, interval \(seg.frameInterval)s")
        }

        // Show compiling state
        isCompilingVideo = true

        // Create video from captured frames (with audio segments if available)
        let segments = audioSegments
        Task {
            await createVideo(withAudioSegments: segments)
        }
    }

    private func createVideo(withAudioSegments audioSegments: [AudioSegment]) async {
        guard !capturedFrameURLs.isEmpty else {
            print("❌ No frames captured")
            await MainActor.run {
                self.isCompilingVideo = false
                self.compilationProgress = 0
            }
            return
        }

        // Start background task to prevent iOS from killing the app during compilation
        beginBackgroundTask()

        await MainActor.run {
            self.compilationProgress = 0
        }

        let videoOnlyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let totalFrames = capturedFrameURLs.count
        print("🎥 Creating timelapse video from \(totalFrames) frames at \(outputFPS) fps")

        do {
            // Video creation is ~80% of the work, audio merge is ~20%
            try await createVideoFromFrames(
                frameURLs: capturedFrameURLs,
                outputURL: videoOnlyURL,
                fps: outputFPS,
                progressCallback: { [weak self] progress in
                    Task { @MainActor in
                        // Frame processing is 0-80% of total progress
                        self?.compilationProgress = progress * 0.8
                    }
                }
            )

            await MainActor.run {
                self.compilationProgress = 0.8
            }

            // If we have audio segments, merge them with the video using proper sync
            var newVideoURL = videoOnlyURL
            if !audioSegments.isEmpty {
                print("🔊 Merging \(audioSegments.count) audio segment(s) with video using segment-based sync...")
                let audioMergedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                try await mergeVideoWithAudioSegments(
                    videoURL: videoOnlyURL,
                    audioSegments: audioSegments,
                    outputURL: audioMergedURL
                )

                await MainActor.run {
                    self.compilationProgress = 0.85
                }

                // Clean up intermediate files
                try? FileManager.default.removeItem(at: videoOnlyURL)
                for segment in audioSegments {
                    try? FileManager.default.removeItem(at: segment.audioFileURL)
                }

                newVideoURL = audioMergedURL
                print("✅ Audio merged successfully")
            }

            // If in continue mode, concatenate with existing video
            let continueURL = await MainActor.run { self.continueFromVideoURL }
            if let existingVideoURL = continueURL {
                print("🔗 Continue mode: concatenating with existing video...")
                await MainActor.run {
                    self.compilationProgress = 0.9
                }

                let concatenatedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                try await concatenateVideos(
                    firstURL: existingVideoURL,
                    secondURL: newVideoURL,
                    outputURL: concatenatedURL
                )

                // Clean up intermediate new video
                try? FileManager.default.removeItem(at: newVideoURL)

                await MainActor.run {
                    self.recordedVideoURL = concatenatedURL
                    self.isCompilingVideo = false
                    self.compilationProgress = 1.0
                    self.resetContinueMode()
                }
                print("✅ Concatenated video created at: \(concatenatedURL)")
            } else {
                await MainActor.run {
                    self.recordedVideoURL = newVideoURL
                    self.isCompilingVideo = false
                    self.compilationProgress = 1.0
                }
                print("✅ Timelapse video created at: \(newVideoURL)")
            }

            // Clean up temporary frame files
            if let storageDir = frameStorageDirectory {
                try? FileManager.default.removeItem(at: storageDir)
                print("🗑️ Cleaned up frame storage directory")
            }
        } catch {
            print("❌ Failed to create video: \(error)")
            await MainActor.run {
                self.isCompilingVideo = false
                self.compilationProgress = 0
                self.diskSpaceError = "Failed to create video: \(error.localizedDescription)"
            }
        }

        // End background task
        endBackgroundTask()
    }

    /// Concatenate two videos into one
    nonisolated func concatenateVideos(
        firstURL: URL,
        secondURL: URL,
        outputURL: URL
    ) async throws {
        print("🔗 Concatenating videos: \(firstURL.lastPathComponent) + \(secondURL.lastPathComponent)")

        let firstAsset = AVURLAsset(url: firstURL)
        let secondAsset = AVURLAsset(url: secondURL)
        let composition = AVMutableComposition()

        // Load video tracks from both assets
        guard let firstVideoTrack = try await firstAsset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "TimeLapseRecorder", code: -30,
                          userInfo: [NSLocalizedDescriptionKey: "First video has no video track"])
        }

        guard let secondVideoTrack = try await secondAsset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "TimeLapseRecorder", code: -31,
                          userInfo: [NSLocalizedDescriptionKey: "Second video has no video track"])
        }

        // Create composition video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "TimeLapseRecorder", code: -32,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }

        // Get durations
        let firstDuration = try await firstAsset.load(.duration)
        let secondDuration = try await secondAsset.load(.duration)

        // Insert first video
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: firstDuration),
            of: firstVideoTrack,
            at: .zero
        )

        // Insert second video after first
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: secondDuration),
            of: secondVideoTrack,
            at: firstDuration
        )

        // Use transform from first video
        let firstTransform = try await firstVideoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = firstTransform

        print("🔗 First video: \(CMTimeGetSeconds(firstDuration))s, Second: \(CMTimeGetSeconds(secondDuration))s")

        // Handle audio tracks if present
        let firstAudioTracks = try await firstAsset.loadTracks(withMediaType: .audio)
        let secondAudioTracks = try await secondAsset.loadTracks(withMediaType: .audio)

        if !firstAudioTracks.isEmpty || !secondAudioTracks.isEmpty {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw NSError(domain: "TimeLapseRecorder", code: -33,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
            }

            // Insert first audio if present
            if let firstAudioTrack = firstAudioTracks.first {
                try? compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: firstDuration),
                    of: firstAudioTrack,
                    at: .zero
                )
            }

            // Insert second audio after first duration
            if let secondAudioTrack = secondAudioTracks.first {
                try? compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: secondDuration),
                    of: secondAudioTrack,
                    at: firstDuration
                )
            }
        }

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "TimeLapseRecorder", code: -34,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        print("🔗 Starting concatenation export...")
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            let totalDuration = CMTimeGetSeconds(firstDuration) + CMTimeGetSeconds(secondDuration)
            print("✅ Concatenation completed: \(totalDuration)s total")
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("❌ Concatenation failed: \(errorMessage)")
            throw exportSession.error ?? NSError(domain: "TimeLapseRecorder", code: -35,
                          userInfo: [NSLocalizedDescriptionKey: "Export failed: \(errorMessage)"])
        case .cancelled:
            throw NSError(domain: "TimeLapseRecorder", code: -36,
                          userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])
        default:
            throw NSError(domain: "TimeLapseRecorder", code: -37,
                          userInfo: [NSLocalizedDescriptionKey: "Export ended with status: \(exportSession.status.rawValue)"])
        }
    }

    /// Merge speed segments from continue recording, applying proper offsets
    func getMergedSpeedSegmentsJSON() -> String? {
        guard isContinueMode else {
            return getSpeedSegmentsJSON()
        }

        // Offset new segments by previous totals
        let offsetSegments = speedSegments.map { segment in
            SpeedSegment(
                startFrameIndex: segment.startFrameIndex + previousFrameCount,
                endFrameIndex: segment.endFrameIndex + previousFrameCount,
                startRealTime: segment.startRealTime + previousDuration,
                endRealTime: segment.endRealTime + previousDuration,
                frameInterval: segment.frameInterval
            )
        }

        let mergedSegments = previousSpeedSegments + offsetSegments

        guard !mergedSegments.isEmpty else { return nil }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(mergedSegments),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return nil
    }

    /// Get total duration including previous recording (for continue mode)
    func getTotalRecordingDuration() -> TimeInterval {
        return previousDuration + recordingDuration
    }

    /// Pre-process audio file to target duration using AVAssetExportSession
    /// This is the workaround for Apple's scaleTimeRange bug that only scales video, not audio
    /// See: https://nonstrict.eu/blog/2023/stretching-an-audio-file-using-swift/
    nonisolated private func scaleAudioFile(
        inputURL: URL,
        targetDuration: CMTime,
        outputURL: URL
    ) async throws {
        print("   🎵 scaleAudioFile: input=\(inputURL.lastPathComponent), targetDuration=\(CMTimeGetSeconds(targetDuration))s")

        let inputAsset = AVAsset(url: inputURL)
        let inputDuration = try await inputAsset.load(.duration)
        let inputTimeRange = CMTimeRange(start: .zero, duration: inputDuration)
        print("   🎵 Input duration: \(CMTimeGetSeconds(inputDuration))s")

        guard let inputTrack = try await inputAsset.loadTracks(withMediaType: .audio).first else {
            print("   ❌ No audio track in input file")
            throw NSError(domain: "TimeLapseRecorder", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "No audio track in input file"])
        }
        print("   🎵 Audio track loaded")

        // Create composition with audio only
        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("   ❌ Failed to create audio track in composition")
            throw NSError(domain: "TimeLapseRecorder", code: -11,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
        }

        try audioTrack.insertTimeRange(inputTimeRange, of: inputTrack, at: .zero)
        print("   🎵 Audio inserted into composition")

        // Scale the AUDIO-ONLY composition (this works correctly for audio-only compositions)
        composition.scaleTimeRange(inputTimeRange, toDuration: targetDuration)
        print("   🎵 Time range scaled")

        // Export the scaled audio
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("   ❌ Failed to create export session")
            throw NSError(domain: "TimeLapseRecorder", code: -12,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        print("   🎵 Starting audio export...")

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            print("   ✅ Audio scaled: \(CMTimeGetSeconds(inputDuration))s → \(CMTimeGetSeconds(targetDuration))s")
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("   ❌ Audio export failed: \(errorMessage)")
            throw exportSession.error ?? NSError(domain: "TimeLapseRecorder", code: -13,
                          userInfo: [NSLocalizedDescriptionKey: "Audio export failed: \(errorMessage)"])
        case .cancelled:
            print("   ❌ Audio export cancelled")
            throw NSError(domain: "TimeLapseRecorder", code: -17,
                          userInfo: [NSLocalizedDescriptionKey: "Audio export cancelled"])
        default:
            print("   ❌ Audio export ended with status: \(exportSession.status.rawValue)")
            throw NSError(domain: "TimeLapseRecorder", code: -18,
                          userInfo: [NSLocalizedDescriptionKey: "Audio export status: \(exportSession.status.rawValue)"])
        }
    }

    nonisolated private func mergeVideoWithAudioSegments(
        videoURL: URL,
        audioSegments: [AudioSegment],
        outputURL: URL
    ) async throws {
        print("🎬 Starting merge: video=\(videoURL.lastPathComponent), audioSegments=\(audioSegments.count)")

        let videoAsset = AVURLAsset(url: videoURL)
        let composition = AVMutableComposition()

        // Add video track
        print("📹 Loading video track...")
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "TimeLapseRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }

        let videoDuration = try await videoAsset.load(.duration)
        print("📹 Video duration: \(CMTimeGetSeconds(videoDuration))s")
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        print("📹 Video track inserted")

        // Copy video transform
        let videoTransform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = videoTransform

        // Create audio track for composition
        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "TimeLapseRecorder", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
        }
        print("🔊 Audio track created in composition")

        let fps = Double(await MainActor.run { self.outputFPS })
        print("🔊 FPS: \(fps)")

        // Process each audio segment
        // Since audio is only recorded in Normal mode, we just insert directly (no speedup needed)
        for (index, segment) in audioSegments.enumerated() {
            let audioAsset = AVURLAsset(url: segment.audioFileURL)

            guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
                print("⚠️ No audio track in segment \(index), skipping")
                continue
            }

            let audioDuration = try await audioAsset.load(.duration)
            let audioDurationSeconds = CMTimeGetSeconds(audioDuration)

            // Calculate video position from frame index
            // Add latency compensation (AVAudioRecorder startup delay)
            // Audio timestamp is captured before recorder actually starts, so audio plays slightly early without compensation
            let audioStartupLatency: Double = 0.15 // 150ms compensation
            let videoPositionSeconds = max(0, (Double(segment.startFrameIndex) / fps) + audioStartupLatency)
            let videoPosition = CMTime(seconds: videoPositionSeconds, preferredTimescale: 600)

            print("🔊 Audio segment \(index):")
            print("   Start frame: \(segment.startFrameIndex)")
            print("   Video position: \(String(format: "%.2f", videoPositionSeconds))s")
            print("   Audio duration: \(String(format: "%.2f", audioDurationSeconds))s")

            do {
                // Insert audio directly at the correct position (no speedup since Normal mode only)
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: audioDuration),
                    of: audioTrack,
                    at: videoPosition
                )
                print("   ✅ Inserted audio at video position \(String(format: "%.2f", videoPositionSeconds))s")
            } catch {
                print("⚠️ Failed to insert audio segment \(index): \(error)")
            }
        }

        print("🔊 Finished processing all \(audioSegments.count) audio segment(s)")

        // Export
        print("📤 Starting final video export...")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "TimeLapseRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        await exportSession.export()

        // Check export status properly
        switch exportSession.status {
        case .completed:
            print("📤 Export completed successfully")
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("❌ Export failed: \(errorMessage)")
            throw exportSession.error ?? NSError(domain: "TimeLapseRecorder", code: -14,
                          userInfo: [NSLocalizedDescriptionKey: "Export failed: \(errorMessage)"])
        case .cancelled:
            print("❌ Export was cancelled")
            throw NSError(domain: "TimeLapseRecorder", code: -15,
                          userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])
        default:
            print("❌ Export ended with unexpected status: \(exportSession.status.rawValue)")
            throw NSError(domain: "TimeLapseRecorder", code: -16,
                          userInfo: [NSLocalizedDescriptionKey: "Export ended with status: \(exportSession.status.rawValue)"])
        }
    }

    nonisolated private func createVideoFromFrames(
        frameURLs: [URL],
        outputURL: URL,
        fps: Int32,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws {
        // Load first frame to get dimensions
        guard let firstFrameData = try? Data(contentsOf: frameURLs[0]),
              let firstImage = UIImage(data: firstFrameData),
              let firstCGImage = firstImage.cgImage else {
            throw NSError(domain: "TimeLapseRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load first frame"])
        }

        let width = firstCGImage.width
        let height = firstCGImage.height
        let totalFrames = frameURLs.count

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        // Apply transform based on the orientation at recording time
        // iPhone captures landscape natively, so we rotate accordingly
        await MainActor.run {
            writerInput.transform = self.transformForOrientation(self.recordingOrientation)
        }

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        writer.add(writerInput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)

        let queue = DispatchQueue(label: "com.lockin.timelapse.write")

        // Track last progress update to avoid too frequent callbacks
        var lastProgressUpdate: Int = 0
        let progressUpdateInterval = max(1, totalFrames / 100) // Update ~100 times max

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var frameIndex: Int64 = 0

            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if frameIndex >= frameURLs.count {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            continuation.resume()
                        }
                        return
                    }

                    // Autoreleasepool ensures memory is freed each iteration
                    // Without this, Data/UIImage/CGImage objects accumulate and cause crashes
                    autoreleasepool {
                        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

                        // Load frame from disk
                        if let frameData = try? Data(contentsOf: frameURLs[Int(frameIndex)]),
                           let frameImage = UIImage(data: frameData),
                           let cgImage = frameImage.cgImage,
                           let pixelBuffer = TimeLapseRecorder.createPixelBuffer(from: cgImage, width: width, height: height) {
                            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        }
                    }

                    frameIndex += 1

                    // Report progress periodically
                    let currentFrame = Int(frameIndex)
                    if currentFrame - lastProgressUpdate >= progressUpdateInterval {
                        lastProgressUpdate = currentFrame
                        let progress = Double(currentFrame) / Double(totalFrames)
                        progressCallback?(progress)
                    }
                }
            }
        }

        // Final progress update
        progressCallback?(1.0)
    }

    private func transformForOrientation(_ orientation: UIDeviceOrientation) -> CGAffineTransform {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let isFrontCamera = currentCameraPosition == .front

        if isIPad {
            // iPad camera behavior differs from iPhone
            // iPad front camera is on the landscape edge, so orientations are different
            switch orientation {
            case .portrait:
                if isFrontCamera {
                    // iPad front camera portrait: rotate -90° (270°) and mirror
                    return CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
                } else {
                    return CGAffineTransform(rotationAngle: -.pi / 2)
                }
            case .landscapeLeft:
                if isFrontCamera {
                    // iPad front camera landscape left: rotate 180° and mirror
                    return CGAffineTransform(rotationAngle: .pi).scaledBy(x: -1, y: 1)
                } else {
                    return CGAffineTransform(rotationAngle: .pi)
                }
            case .landscapeRight:
                if isFrontCamera {
                    // iPad front camera landscape right: no rotation, just mirror
                    return CGAffineTransform(scaleX: -1, y: 1)
                } else {
                    return CGAffineTransform.identity
                }
            default:
                if isFrontCamera {
                    return CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
                } else {
                    return CGAffineTransform(rotationAngle: -.pi / 2)
                }
            }
        } else {
            // iPhone behavior
            switch orientation {
            case .portrait:
                if isFrontCamera {
                    // Front camera portrait: 90-degree counter-clockwise rotation + mirror
                    return CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
                } else {
                    // Back camera portrait: 90-degree clockwise rotation
                    return CGAffineTransform(rotationAngle: .pi / 2)
                }
            case .landscapeLeft:
                if isFrontCamera {
                    // Front camera landscape left: 180-degree rotation + mirror
                    return CGAffineTransform(rotationAngle: .pi).scaledBy(x: -1, y: 1)
                } else {
                    // Back camera landscape left: No rotation needed
                    return CGAffineTransform.identity
                }
            case .landscapeRight:
                if isFrontCamera {
                    // Front camera landscape right: mirror horizontally only
                    return CGAffineTransform(scaleX: -1, y: 1)
                } else {
                    // Back camera landscape right: 180-degree rotation
                    return CGAffineTransform(rotationAngle: .pi)
                }
            default:
                if isFrontCamera {
                    return CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: -1, y: 1)
                } else {
                    return CGAffineTransform(rotationAngle: .pi / 2)
                }
            }
        }
    }

    nonisolated private static func createPixelBuffer(from image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    func switchCamera() {
        guard !isRecording else { return }
        guard let currentInput = currentVideoInput else { return }

        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front

        var newVideoDevice: AVCaptureDevice?

        // For back camera, try to use virtual device for seamless zoom
        if newPosition == .back {
            newVideoDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            if newVideoDevice == nil {
                newVideoDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            }
        }

        // Fall back to wide angle for front camera or if virtual not available
        if newVideoDevice == nil {
            newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition)
        }

        guard let device = newVideoDevice,
              let newVideoInput = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)

        if captureSession.canAddInput(newVideoInput) {
            captureSession.addInput(newVideoInput)
            currentVideoInput = newVideoInput
            currentCameraPosition = newPosition

            // Check if we're using a virtual device (has ultra-wide)
            let deviceType = device.deviceType
            if deviceType == .builtInTripleCamera || deviceType == .builtInDualWideCamera {
                hasUltraWide = true
                isUsingVirtualDevice = true
                // Set to 1x (zoom factor 2.0 on virtual device)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = 2.0
                    device.unlockForConfiguration()
                } catch {
                    print("❌ Failed to set initial zoom: \(error)")
                }
            } else {
                hasUltraWide = false
                isUsingVirtualDevice = false
            }
            currentZoomLevel = 1.0
        } else {
            captureSession.addInput(currentInput)
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Zoom Control

    /// Toggle between 0.5x (ultra-wide) and 1x (normal) zoom
    /// Uses virtual device - zoom factor 1.0 = ultra-wide (0.5x), 2.0 = wide (1x)
    func cycleZoom() {
        guard hasUltraWide, isUsingVirtualDevice else {
            print("⚠️ Ultra-wide not available (front camera or unsupported device)")
            return
        }

        guard let device = currentVideoInput?.device else { return }

        // Toggle between 0.5x and 1x
        let newZoomLevel: CGFloat = currentZoomLevel == 1.0 ? 0.5 : 1.0
        // Virtual device mapping: 0.5x = factor 1.0, 1x = factor 2.0
        let zoomFactor: CGFloat = newZoomLevel == 0.5 ? 1.0 : 2.0

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
            currentZoomLevel = newZoomLevel
            print("📷 Zoom: \(newZoomLevel)x (factor: \(zoomFactor))")
        } catch {
            print("❌ Failed to set zoom: \(error)")
        }
    }

    func clearFrames() {
        capturedFrameURLs.removeAll()
        frameTimestamps.removeAll()
        speedSegments.removeAll()
        frameCount = 0
        recordedVideoURL = nil
        isIphoneMode = false  // Reset iPhone Mode state
        iphoneModeCurrentTier = 0  // Reset tier tracking
        iphoneModeRealDuration = 0  // Reset real duration
        resetContinueMode()   // Reset continue mode state

        // Clean up temporary frame storage
        if let storageDir = frameStorageDirectory {
            try? FileManager.default.removeItem(at: storageDir)
            frameStorageDirectory = nil
        }

        // Clean up audio segments
        for segment in audioSegments {
            try? FileManager.default.removeItem(at: segment.audioFileURL)
        }
        audioSegments.removeAll()

        // Clean up current audio file
        if let audioURL = currentAudioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
            currentAudioFileURL = nil
        }
    }

    // MARK: - Voiceover

    /// Add voiceover audio to an existing video, replacing any existing audio
    nonisolated func addVoiceoverToVideo(videoURL: URL, voiceoverURL: URL, outputURL: URL) async throws {
        print("🎙️ Adding voiceover to video...")

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: voiceoverURL)
        let composition = AVMutableComposition()

        // Add video track (without original audio - we're replacing it)
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw NSError(domain: "TimeLapseRecorder", code: -20,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )

        // Copy video transform
        let videoTransform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = videoTransform

        print("📹 Video track added, duration: \(CMTimeGetSeconds(videoDuration))s")

        // Add voiceover audio track (replaces any existing audio)
        if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw NSError(domain: "TimeLapseRecorder", code: -21,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to create audio track"])
            }

            let audioDuration = try await audioAsset.load(.duration)
            // Use the shorter of video or audio duration
            let insertDuration = CMTimeMinimum(videoDuration, audioDuration)

            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: insertDuration),
                of: audioTrack,
                at: .zero
            )

            print("🔊 Voiceover audio added, duration: \(CMTimeGetSeconds(audioDuration))s")
        } else {
            print("⚠️ No audio track found in voiceover file")
        }

        // Export the final video
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "TimeLapseRecorder", code: -22,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        print("📤 Starting voiceover video export...")
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            print("✅ Voiceover video created successfully")
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("❌ Voiceover export failed: \(errorMessage)")
            throw exportSession.error ?? NSError(domain: "TimeLapseRecorder", code: -23,
                          userInfo: [NSLocalizedDescriptionKey: "Export failed: \(errorMessage)"])
        case .cancelled:
            print("❌ Voiceover export cancelled")
            throw NSError(domain: "TimeLapseRecorder", code: -24,
                          userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])
        default:
            print("❌ Voiceover export ended with status: \(exportSession.status.rawValue)")
            throw NSError(domain: "TimeLapseRecorder", code: -25,
                          userInfo: [NSLocalizedDescriptionKey: "Export ended with status: \(exportSession.status.rawValue)"])
        }
    }

    func cleanup() {
        stopRecording()
        captureSession.stopRunning()
        capturedFrameURLs.removeAll()
        frameTimestamps.removeAll()
        speedSegments.removeAll()

        // Stop orientation observer
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()

        // Clean up recorded video
        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }

        // Clean up temporary frame storage
        if let storageDir = frameStorageDirectory {
            try? FileManager.default.removeItem(at: storageDir)
            frameStorageDirectory = nil
        }

        // Clean up audio segments
        for segment in audioSegments {
            try? FileManager.default.removeItem(at: segment.audioFileURL)
        }
        audioSegments.removeAll()

        // Clean up current audio file
        if let audioURL = currentAudioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
            currentAudioFileURL = nil
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension TimeLapseRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor in
            guard isRecording && !isPaused else { return }
            guard let storageDir = frameStorageDirectory else { return }

            let now = Date()

            // Check if enough time has passed since last capture
            // frameInterval = 0 means capture every frame (real-time mode)
            if frameInterval > 0 {
                if let lastTime = lastCaptureTime,
                   now.timeIntervalSince(lastTime) < frameInterval {
                    return
                }
            }

            lastCaptureTime = now

            // Record frame timestamp for audio sync
            // Use actual wall clock time for accuracy (not timer-updated recordingDuration)
            let actualRealTime = calculateActualRealTime()
            let timestamp = FrameTimestamp(
                frameIndex: frameCount,
                realTimeOffset: actualRealTime
            )
            frameTimestamps.append(timestamp)

            // Capture frame with reduced quality
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let ciImage = CIImage(cvPixelBuffer: imageBuffer)

            // Scale down to 720p for lower memory usage
            let targetWidth: CGFloat = 1280
            let targetHeight: CGFloat = 720
            let scaleX = targetWidth / ciImage.extent.width
            let scaleY = targetHeight / ciImage.extent.height
            let scale = min(scaleX, scaleY)

            let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            let context = CIContext(options: [.useSoftwareRenderer: false])
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }

            // Save frame to disk as JPEG
            let frameURL = storageDir.appendingPathComponent("frame_\(frameCount).jpg")
            let uiImage = UIImage(cgImage: cgImage)

            if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                try? jpegData.write(to: frameURL)
                capturedFrameURLs.append(frameURL)
                frameCount = capturedFrameURLs.count

                if frameCount % 10 == 0 {
                    print("📸 Captured \(frameCount) frames at real-time \(String(format: "%.2f", actualRealTime))s")
                }
            }
        }
    }
}
