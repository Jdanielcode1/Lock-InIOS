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
struct SpeedSegment {
    let startFrameIndex: Int      // First frame index in this segment
    var endFrameIndex: Int        // Last frame index (exclusive)
    let startRealTime: TimeInterval  // Real time when segment started (excluding pauses)
    var endRealTime: TimeInterval    // Real time when segment ended
    let frameInterval: TimeInterval  // Capture interval during this segment
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
    @Published var recordingDuration: TimeInterval = 0
    @Published var frameCount: Int = 0
    @Published var recordedVideoURL: URL?
    @Published var currentCaptureRate: String = "2 fps"
    @Published var deviceOrientation: UIDeviceOrientation = .portrait
    @Published var isAudioEnabled = false // Audio recording toggle (disabled by default)

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

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
    private let maxRecordingDuration: TimeInterval = 4 * 60 * 60 // 4 hours in seconds

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
    func setCaptureInterval(_ interval: TimeInterval, rateName: String) {
        let isNormalMode = interval <= 0
        let wasNormalMode = frameInterval <= 0

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
        manualSpeedOverride = true
        print("📸 User changed capture rate to \(rateName) (interval: \(interval)s)")
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

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(videoInput)
        currentVideoInput = videoInput

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
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }

                // Calculate duration excluding paused time
                var totalPaused = self.pausedDuration
                if self.isPaused, let pauseStart = self.pauseStartTime {
                    totalPaused += Date().timeIntervalSince(pauseStart)
                }
                self.recordingDuration = Date().timeIntervalSince(start) - totalPaused

                self.updateFrameInterval()

                // Check if max duration reached (4 hours)
                if self.recordingDuration >= self.maxRecordingDuration {
                    print("⏰ Maximum recording duration reached (4 hours). Stopping recording...")
                    self.stopRecording()
                }
            }
        }

        print("🎬 Started timelapse recording at \(currentCaptureRate) (max 4 hours)")
    }

    private func updateFrameInterval() {
        // User controls the speed manually via speed selector
        // No automatic adjustment
    }

    func stopRecording() {
        // Capture actual time before stopping timer
        let finalTime = calculateActualRealTime()

        isRecording = false
        isPaused = false
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

        // Create video from captured frames (with audio segments if available)
        let segments = audioSegments
        Task {
            await createVideo(withAudioSegments: segments)
        }
    }

    private func createVideo(withAudioSegments audioSegments: [AudioSegment]) async {
        guard !capturedFrameURLs.isEmpty else {
            print("❌ No frames captured")
            return
        }

        let videoOnlyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        print("🎥 Creating timelapse video from \(capturedFrameURLs.count) frames at \(outputFPS) fps")

        do {
            try await createVideoFromFrames(frameURLs: capturedFrameURLs, outputURL: videoOnlyURL, fps: outputFPS)

            // If we have audio segments, merge them with the video using proper sync
            if !audioSegments.isEmpty {
                print("🔊 Merging \(audioSegments.count) audio segment(s) with video using segment-based sync...")
                let finalURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                try await mergeVideoWithAudioSegments(
                    videoURL: videoOnlyURL,
                    audioSegments: audioSegments,
                    outputURL: finalURL
                )

                // Clean up intermediate files
                try? FileManager.default.removeItem(at: videoOnlyURL)
                for segment in audioSegments {
                    try? FileManager.default.removeItem(at: segment.audioFileURL)
                }

                await MainActor.run {
                    self.recordedVideoURL = finalURL
                }
                print("✅ Timelapse video with synced audio created at: \(finalURL)")
            } else {
                await MainActor.run {
                    self.recordedVideoURL = videoOnlyURL
                }
                print("✅ Timelapse video created at: \(videoOnlyURL)")
            }

            // Clean up temporary frame files
            if let storageDir = frameStorageDirectory {
                try? FileManager.default.removeItem(at: storageDir)
                print("🗑️ Cleaned up frame storage directory")
            }
        } catch {
            print("❌ Failed to create video: \(error)")
        }
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
            let videoPositionSeconds = Double(segment.startFrameIndex) / fps
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

    nonisolated private func createVideoFromFrames(frameURLs: [URL], outputURL: URL, fps: Int32) async throws {
        // Load first frame to get dimensions
        guard let firstFrameData = try? Data(contentsOf: frameURLs[0]),
              let firstImage = UIImage(data: firstFrameData),
              let firstCGImage = firstImage.cgImage else {
            throw NSError(domain: "TimeLapseRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load first frame"])
        }

        let width = firstCGImage.width
        let height = firstCGImage.height

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

                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

                    // Load frame from disk
                    if let frameData = try? Data(contentsOf: frameURLs[Int(frameIndex)]),
                       let frameImage = UIImage(data: frameData),
                       let cgImage = frameImage.cgImage,
                       let pixelBuffer = TimeLapseRecorder.createPixelBuffer(from: cgImage, width: width, height: height) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }

                    frameIndex += 1
                }
            }
        }
    }

    private func transformForOrientation(_ orientation: UIDeviceOrientation) -> CGAffineTransform {
        switch orientation {
        case .portrait:
            // Portrait: 90-degree clockwise rotation
            return CGAffineTransform(rotationAngle: .pi / 2)
        case .landscapeLeft:
            // Landscape left: No rotation needed
            return CGAffineTransform.identity
        case .landscapeRight:
            // Landscape right: 180-degree rotation
            return CGAffineTransform(rotationAngle: .pi)
        default:
            // Default to portrait
            return CGAffineTransform(rotationAngle: .pi / 2)
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

        guard let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newVideoInput = try? AVCaptureDeviceInput(device: newVideoDevice) else {
            return
        }

        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)

        if captureSession.canAddInput(newVideoInput) {
            captureSession.addInput(newVideoInput)
            currentVideoInput = newVideoInput
            currentCameraPosition = newPosition
        } else {
            captureSession.addInput(currentInput)
        }

        captureSession.commitConfiguration()
    }

    func clearFrames() {
        capturedFrameURLs.removeAll()
        frameTimestamps.removeAll()
        speedSegments.removeAll()
        frameCount = 0
        recordedVideoURL = nil

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
