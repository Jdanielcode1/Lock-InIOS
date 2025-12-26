//
//  VideoRecorderView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import PhotosUI

struct VideoRecorderView: View {
    let goalId: String
    let subtaskId: String?

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: VideoRecorderViewModel

    init(goalId: String, subtaskId: String?) {
        self.goalId = goalId
        self.subtaskId = subtaskId
        _viewModel = StateObject(wrappedValue: VideoRecorderViewModel(goalId: goalId, subtaskId: subtaskId))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(AppTheme.energyGradient)

                        Text("Add Study Session")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Select a time-lapse video of your study session")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Video picker or upload progress
                    if viewModel.isUploading {
                        uploadProgressView
                    } else if let videoURL = viewModel.selectedVideoURL {
                        selectedVideoView(url: videoURL)
                    } else {
                        videoPickerButton
                    }

                    Spacer()

                    // Save button
                    if viewModel.selectedVideoURL != nil && !viewModel.isUploading {
                        Button {
                            Task {
                                await viewModel.saveVideo()
                                if viewModel.uploadSuccess {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save & Add to Goal")
                            }
                            .font(AppTheme.headlineFont)
                            .frame(maxWidth: .infinity)
                        }
                        .primaryButton()
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.actionBlue)
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
    }

    var videoPickerButton: some View {
        VStack(spacing: 20) {
            Button {
                viewModel.showingVideoPicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("Select Video")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Choose a time-lapse video from your library")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .playfulCard()
            }
        }
        .sheet(isPresented: $viewModel.showingVideoPicker) {
            VideoPicker(videoURL: $viewModel.selectedVideoURL)
        }
    }

    func selectedVideoView(url: URL) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.primaryGradient)
                    .frame(height: 200)

                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    Text("Video Selected")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(.white)

                    if let duration = viewModel.estimatedDuration {
                        Text("Duration: \(Int(duration)) minutes")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .playfulCard()

            Button {
                viewModel.selectedVideoURL = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Choose Different Video")
                }
                .font(AppTheme.bodyFont)
            }
            .secondaryButton()
        }
        .task {
            await viewModel.calculateVideoDuration()
        }
    }

    var uploadProgressView: some View {
        VStack(spacing: 24) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppTheme.borderLight, lineWidth: 12)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: viewModel.uploadProgress)
                    .stroke(
                        AppTheme.energyGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(AppTheme.smoothAnimation, value: viewModel.uploadProgress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.uploadProgress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(viewModel.uploadStatusText)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Text("Saving your study session...")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("This may take a moment")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .playfulCard()
    }
}

// ViewModel for VideoRecorderView
@MainActor
class VideoRecorderViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var showingVideoPicker = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadStatusText = "Preparing..."
    @Published var errorMessage: String?
    @Published var uploadSuccess = false
    @Published var estimatedDuration: Double?

    private let goalId: String
    private let subtaskId: String?
    private let videoService = VideoService.shared

    init(goalId: String, subtaskId: String?) {
        self.goalId = goalId
        self.subtaskId = subtaskId
    }

    func calculateVideoDuration() async {
        guard let url = selectedVideoURL else { return }

        do {
            estimatedDuration = try await videoService.getVideoDuration(url: url)
        } catch {
            errorMessage = "Failed to read video: \(error.localizedDescription)"
        }
    }

    func saveVideo() async {
        guard let url = selectedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            // Get video duration
            let durationMinutes = estimatedDuration ?? 0
            uploadStatusText = "Compressing video..."
            uploadProgress = 0.2

            // Save video to local storage
            let localVideoPath = try LocalStorageService.shared.saveVideo(from: url)
            uploadStatusText = "Saving to device..."
            uploadProgress = 0.5

            // Generate and save thumbnail
            var localThumbnailPath: String? = nil
            if let fullURL = LocalStorageService.shared.getFullURL(for: localVideoPath) {
                if let thumbnail = try? await videoService.generateThumbnail(from: fullURL) {
                    localThumbnailPath = try? LocalStorageService.shared.saveThumbnail(thumbnail)
                }
            }
            uploadStatusText = "Finalizing..."
            uploadProgress = 0.7

            // Create study session with local path
            _ = try await ConvexService.shared.createStudySession(
                goalId: goalId,
                subtaskId: subtaskId,
                localVideoPath: localVideoPath,
                localThumbnailPath: localThumbnailPath,
                durationMinutes: durationMinutes
            )

            uploadProgress = 1.0
            uploadStatusText = "Complete!"
            uploadSuccess = true

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)

        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0
        }
    }
}

// Video Picker using PhotosUI
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url else { return }

                // Copy to temporary location
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                try? FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    self.parent.videoURL = tempURL
                }
            }
        }
    }
}

#Preview {
    VideoRecorderView(goalId: "123", subtaskId: nil)
}
