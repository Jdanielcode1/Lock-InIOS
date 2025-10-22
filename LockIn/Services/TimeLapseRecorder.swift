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

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    var capturedFrames: [CGImage] = []
    private var startTime: Date?
    private var lastCaptureTime: Date?
    private var frameInterval: TimeInterval = 0.5 // Dynamic: starts at 2 fps
    private let outputFPS: Int32 = 30 // Playback at 30 fps

    private var recordingTimer: Timer?
    private let videoQueue = DispatchQueue(label: "com.lockin.timelapse.video")

    func setupCamera() async {
        await requestCameraPermission()
        await configureCaptureSession()
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
        capturedFrames.removeAll()
        frameCount = 0
        recordingDuration = 0
        startTime = Date()
        lastCaptureTime = nil
        frameInterval = 0.5 // Start at 2 fps
        currentCaptureRate = "2 fps"

        // Start timer to update duration and frame interval
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
                self.updateFrameInterval()
            }
        }

        print("🎬 Started timelapse recording at 2 fps")
    }

    private func updateFrameInterval() {
        let minutes = recordingDuration / 60.0

        let (newInterval, rateText): (TimeInterval, String) = {
            switch minutes {
            case 0..<10:
                return (0.5, "2 fps")      // Under 10 min: 2 fps
            case 10..<20:
                return (1.0, "1 fps")      // 10-20 min: 1 fps
            case 20..<80:
                return (2.0, "0.5 fps")    // 20-80 min: 0.5 fps
            default:
                return (30.0, "1/30s")     // Over 80 min: ~0.03 fps
            }
        }()

        if frameInterval != newInterval {
            frameInterval = newInterval
            currentCaptureRate = rateText
            print("📸 Adjusted capture rate to \(rateText) at \(Int(minutes)) minutes")
        }
    }

    func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        print("⏹️ Stopped timelapse recording. Captured \(frameCount) frames over \(recordingDuration) seconds")

        // Create video from captured frames
        Task {
            await createVideo()
        }
    }

    private func createVideo() async {
        guard !capturedFrames.isEmpty else {
            print("❌ No frames captured")
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        print("🎥 Creating timelapse video from \(capturedFrames.count) frames at \(outputFPS) fps")

        do {
            try await createVideoFromFrames(frames: capturedFrames, outputURL: outputURL, fps: outputFPS)
            await MainActor.run {
                self.recordedVideoURL = outputURL
            }
            print("✅ Timelapse video created at: \(outputURL)")
        } catch {
            print("❌ Failed to create video: \(error)")
        }
    }

    nonisolated private func createVideoFromFrames(frames: [CGImage], outputURL: URL, fps: Int32) async throws {
        guard let firstFrame = frames.first else { return }

        let width = firstFrame.width
        let height = firstFrame.height

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
                    if frameIndex >= frames.count {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            continuation.resume()
                        }
                        return
                    }

                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))

                    if let pixelBuffer = TimeLapseRecorder.createPixelBuffer(from: frames[Int(frameIndex)], width: width, height: height) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }

                    frameIndex += 1
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
        capturedFrames.removeAll()
        frameCount = 0
        recordedVideoURL = nil
    }

    func cleanup() {
        stopRecording()
        captureSession.stopRunning()
        capturedFrames.removeAll()

        if let url = recordedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
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

            capturedFrames.append(cgImage)
            frameCount = capturedFrames.count

            if frameCount % 10 == 0 {
                print("📸 Captured \(frameCount) frames")
            }
        }
    }
}
