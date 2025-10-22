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

                        Text("Upload Study Session")
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

                    // Upload button
                    if viewModel.selectedVideoURL != nil && !viewModel.isUploading {
                        Button {
                            Task {
                                await viewModel.uploadVideo()
                                if viewModel.uploadSuccess {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upload & Add to Goal")
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
                    .foregroundColor(AppTheme.primaryPurple)
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
                    .stroke(AppTheme.lightPurple.opacity(0.3), lineWidth: 12)
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

            Text("Uploading your study session...")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("This may take a few moments")
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

    func uploadVideo() async {
        guard let url = selectedVideoURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            _ = try await videoService.uploadVideoToConvex(
                videoURL: url,
                goalId: goalId,
                subtaskId: subtaskId
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                    self?.updateStatusText(for: progress)
                }
            }

            uploadSuccess = true

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            isUploading = false
            uploadProgress = 0
        }
    }

    private func updateStatusText(for progress: Double) {
        switch progress {
        case 0..<0.3:
            uploadStatusText = "Compressing video..."
        case 0.3..<0.4:
            uploadStatusText = "Preparing upload..."
        case 0.4..<0.8:
            uploadStatusText = "Uploading..."
        case 0.8..<1.0:
            uploadStatusText = "Finalizing..."
        default:
            uploadStatusText = "Complete!"
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
