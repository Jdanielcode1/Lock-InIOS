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
    let goalTodoId: String?

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: VideoRecorderViewModel

    init(goalId: String, goalTodoId: String?) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        _viewModel = StateObject(wrappedValue: VideoRecorderViewModel(goalId: goalId, goalTodoId: goalTodoId))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentColor)

                        Text("Add Study Session")
                            .font(.title.bold())
                            .foregroundColor(.primary)

                        Text("Select a time-lapse video of your study session")
                            .font(.body)
                            .foregroundColor(.secondary)
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
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
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
    }

    var videoPickerButton: some View {
        VStack(spacing: 20) {
            Button {
                viewModel.showingVideoPicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)

                    Text("Select Video")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Choose a time-lapse video from your library")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
        }
        .sheet(isPresented: $viewModel.showingVideoPicker) {
            VideoPicker(videoURL: $viewModel.selectedVideoURL)
        }
    }

    func selectedVideoView(url: URL) -> some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor)
                    .frame(height: 200)

                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    Text("Video Selected")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let duration = viewModel.estimatedDuration {
                        Text("Duration: \(Int(duration)) minutes")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .cornerRadius(16)

            Button {
                viewModel.selectedVideoURL = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Choose Different Video")
                }
                .font(.body)
                .foregroundStyle(Color.accentColor)
            }
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
                    .stroke(Color(UIColor.separator), lineWidth: 12)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: viewModel.uploadProgress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)

                VStack(spacing: 4) {
                    Text("\(Int(viewModel.uploadProgress * 100))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)

                    Text(viewModel.uploadStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Saving your study session...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("This may take a moment")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
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
    private let goalTodoId: String?
    private let videoService = VideoService.shared

    init(goalId: String, goalTodoId: String?) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
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
    VideoRecorderView(goalId: "123", goalTodoId: nil)
}
