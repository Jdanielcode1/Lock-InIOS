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
        .sheet(isPresented: $showShareSheet) {
            if let videoURL = recapService.compiledVideoURL {
                ShareSheetView(videoURL: videoURL)
            }
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

            // Overlay controls
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
        }
    }

    // MARK: - Functions

    private func setupPlayer(url: URL) {
        player = AVPlayer(url: url)
        player?.play()

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

// MARK: - Share Sheet View (simple wrapper)

struct ShareSheetView: UIViewControllerRepresentable {
    let videoURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    DailyRecapButton(todosWithVideos: [])
}
