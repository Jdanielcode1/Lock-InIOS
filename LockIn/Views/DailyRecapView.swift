//
//  DailyRecapView.swift
//  LockIn
//
//  Created by Claude on 31/12/25.
//

import SwiftUI
import AVKit
import Photos

// MARK: - Daily Recap Button (for Timeline header)

struct DailyRecapButton: View {
    let todosWithVideos: [TodoItem]
    @State private var showingRecapSheet = false

    var body: some View {
        Button {
            showingRecapSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "film.stack")
                    .font(.system(size: 12, weight: .semibold))
                Text("Recap")
                    .font(.system(size: 12, weight: .semibold))
                Text("(\(todosWithVideos.count))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .fullScreenCover(isPresented: $showingRecapSheet) {
            DailyRecapView(todos: todosWithVideos)
        }
    }
}

// MARK: - Daily Recap Full Screen View

struct DailyRecapView: View {
    let todos: [TodoItem]
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var recapService = DailyRecapService.shared

    @State private var player: AVPlayer?
    @State private var showShareSheet = false
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false
    @State private var showingErrorAlert = false
    @State private var currentOverlayTitle: String?
    @State private var overlayOpacity: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if recapService.isCompiling {
                compilingView
            } else if let videoURL = recapService.compiledVideoURL {
                videoPlayerView(url: videoURL)
            } else {
                startView
            }
        }
        .alert("Save Video", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recapService.errorMessage ?? "An unknown error occurred")
        }
        .shareSheet(isPresented: $showShareSheet, videoURL: recapService.compiledVideoURL ?? URL(fileURLWithPath: "")) {
            saveVideoToCameraRoll()
        }
        .onDisappear {
            // Don't reset here - let cleanup happen on explicit dismiss
        }
    }

    // MARK: - Start View

    var startView: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button {
                    cleanupAndDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()

            // Preview info
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Daily Recap")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("\(todos.count) completed task\(todos.count == 1 ? "" : "s") with videos")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                // Todo list preview
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(todos.prefix(5)) { todo in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            Text(todo.title)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    if todos.count > 5 {
                        HStack {
                            Text("+ \(todos.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .frame(maxWidth: 300)

                // Duration estimate
                let totalDuration = min(Double(todos.count) * 12, Double(todos.count) * 12)
                Text("~\(Int(totalDuration)) seconds")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Create button
            Button {
                Task {
                    do {
                        print("Starting Daily Recap compilation...")
                        _ = try await recapService.compileDailyRecap(todos: todos)
                        print("Daily Recap compilation completed!")
                    } catch {
                        print("Daily Recap error: \(error)")
                        await MainActor.run {
                            recapService.errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Create Recap")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(28)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Compiling View

    var compilingView: some View {
        VStack(spacing: 30) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: recapService.compilationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: recapService.compilationProgress)

                VStack(spacing: 4) {
                    Text("\(Int(recapService.compilationProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            VStack(spacing: 8) {
                Text("Creating your Daily Recap")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Compiling \(todos.count) videos...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(50)
    }

    // MARK: - Video Player View

    func videoPlayerView(url: URL) -> some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            // Todo title overlay (top-left)
            VStack {
                HStack {
                    if let title = currentOverlayTitle {
                        TodoOverlayBadge(title: title)
                            .opacity(overlayOpacity)
                            .animation(.easeInOut(duration: 0.3), value: overlayOpacity)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 120)

                Spacer()
            }

            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        cleanupAndDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        // Save button
                        Button {
                            saveVideoToCameraRoll()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Bottom info
                VStack(spacing: 8) {
                    Text("Daily Recap")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("\(todos.count) tasks completed")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            setupPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
        }
    }

    // MARK: - Functions

    private func setupPlayer(url: URL) {
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        player?.play()

        // Add time observer for overlay updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            let currentSeconds = CMTimeGetSeconds(time)
            updateOverlay(forTime: currentSeconds)
        }

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

    private func updateOverlay(forTime currentSeconds: Double) {
        let clipTimings = recapService.clipTimings
        let displayDuration = 3.0  // Show overlay for 3 seconds
        let fadeInDuration = 0.3
        let fadeOutDuration = 0.4

        // Find which clip we're in
        for timing in clipTimings {
            let endTime = timing.startTime + min(timing.duration, displayDuration)

            if currentSeconds >= timing.startTime && currentSeconds <= endTime {
                // We're in this clip's overlay time
                let timeIntoOverlay = currentSeconds - timing.startTime
                let timeUntilEnd = endTime - currentSeconds

                // Calculate opacity for fade in/out
                var newOpacity: Double = 1.0
                if timeIntoOverlay < fadeInDuration {
                    newOpacity = timeIntoOverlay / fadeInDuration
                } else if timeUntilEnd < fadeOutDuration {
                    newOpacity = timeUntilEnd / fadeOutDuration
                }

                withAnimation(.easeInOut(duration: 0.1)) {
                    currentOverlayTitle = timing.title
                    overlayOpacity = newOpacity
                }
                return
            }
        }

        // No overlay should be visible
        if currentOverlayTitle != nil {
            withAnimation(.easeOut(duration: 0.3)) {
                overlayOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if overlayOpacity == 0 {
                    currentOverlayTitle = nil
                }
            }
        }
    }

    private func cleanupAndDismiss() {
        player?.pause()
        player = nil

        // Clean up temp file
        if let url = recapService.compiledVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        recapService.reset()

        dismiss()
    }

    private func saveVideoToCameraRoll() {
        guard let videoURL = recapService.compiledVideoURL else { return }

        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            isSaving = false
                            saveAlertMessage = success ?
                                "Video saved to Camera Roll" :
                                "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
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

// MARK: - Todo Overlay Badge

struct TodoOverlayBadge: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            // Checkmark circle
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            // Title text
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    DailyRecapButton(todosWithVideos: [])
}
