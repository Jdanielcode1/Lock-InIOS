//
//  TimeLapseRecorder.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import AVFoundation
import UIKit

@MainActor
class TimeLapseRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
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
    private var audioFileURL: URL?

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
    private var recordingOrientation: UIDeviceOrientation = .portrait

    // Allow external control of capture interval
    func setCaptureInterval(_ interval: TimeInterval, rateName: String) {
        frameInterval = interval
        currentCaptureRate = rateName
        manualSpeedOverride = true
        print("📸 User changed capture rate to \(rateName) (interval: \(interval)s)")
    }

    // Toggle audio recording on/off (can be called during recording)
    func toggleAudio() {
        isAudioEnabled.toggle()

        if isRecording {
            if isAudioEnabled {
                startAudioRecording()
            } else {
                stopAudioRecording()
            }
        }

        print("🎤 Audio \(isAudioEnabled ? "enabled" : "disabled")")
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
            audioFileURL = audioURL
            print("🎙️ Started audio recording: \(audioURL.lastPathComponent)")
        } catch {
            print("❌ Failed to start audio recording: \(error)")
        }
    }

    private func stopAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
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
        capturedFrameURLs.removeAll()
        frameCount = 0
        recordingDuration = 0
        startTime = Date()
        lastCaptureTime = nil
        // Keep current frameInterval (set by user via speed selector)
        // Default is 2.0 seconds (Timelapse mode)

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
            startAudioRecording()
        }

        // Start timer to update duration and frame interval
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
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
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop audio recording
        stopAudioRecording()

        print("⏹️ Stopped timelapse recording. Captured \(frameCount) frames over \(recordingDuration) seconds")

        // Create video from captured frames (with audio if available)
        let audioURL = audioFileURL
        Task {
            await createVideo(withAudioURL: audioURL)
        }
    }

    private func createVideo(withAudioURL audioURL: URL? = nil) async {
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

            // If we have audio, merge it with the video
            if let audioURL = audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
                print("🔊 Merging audio with video...")
                let finalURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                try await mergeVideoWithAudio(videoURL: videoOnlyURL, audioURL: audioURL, outputURL: finalURL)

                // Clean up intermediate files
                try? FileManager.default.removeItem(at: videoOnlyURL)
                try? FileManager.default.removeItem(at: audioURL)

                await MainActor.run {
                    self.recordedVideoURL = finalURL
                    self.audioFileURL = nil
                }
                print("✅ Timelapse video with audio created at: \(finalURL)")
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

    nonisolated private func mergeVideoWithAudio(videoURL: URL, audioURL: URL, outputURL: URL) async throws {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "TimeLapseRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)

        // Copy video transform
        let videoTransform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = videoTransform

        // Add audio track - time-scaled to match video duration
        if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {

            let audioDuration = try await audioAsset.load(.duration)

            // Insert the full audio, then we'll scale it
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: audioDuration),
                of: audioTrack,
                at: .zero
            )

            // Scale the audio track to match video duration
            // This speeds up/slows down the audio to sync with the timelapse
            compositionAudioTrack.scaleTimeRange(
                CMTimeRange(start: .zero, duration: audioDuration),
                toDuration: videoDuration
            )
        }

        // Export
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "TimeLapseRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        await exportSession.export()

        if let error = exportSession.error {
            throw error
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
        frameCount = 0
        recordedVideoURL = nil

        // Clean up temporary frame storage
        if let storageDir = frameStorageDirectory {
            try? FileManager.default.removeItem(at: storageDir)
            frameStorageDirectory = nil
        }

        // Clean up audio file
        if let audioURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
            audioFileURL = nil
        }
    }

    func cleanup() {
        stopRecording()
        captureSession.stopRunning()
        capturedFrameURLs.removeAll()

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

        // Clean up audio file
        if let audioURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
            audioFileURL = nil
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
            guard isRecording else { return }
            guard let storageDir = frameStorageDirectory else { return }

            let now = Date()

            // Check if enough time has passed since last capture
            if let lastTime = lastCaptureTime,
               now.timeIntervalSince(lastTime) < frameInterval {
                return
            }

            lastCaptureTime = now

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
                    print("📸 Captured \(frameCount) frames")
                }
            }
        }
    }
}
