//
//  GoalDetailView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import Combine

struct GoalDetailView: View {
    let goal: Goal

    @StateObject private var viewModel: GoalDetailViewModel
    @State private var showingVideoPicker = false
    @State private var showingTimeLapseRecorder = false
    @State private var showingAddSubtask = false
    @State private var selectedSubtask: Subtask?
    @Environment(\.dismiss) private var dismiss

    init(goal: Goal) {
        self.goal = goal
        _viewModel = StateObject(wrappedValue: GoalDetailViewModel(goalId: goal.id))
    }

    // Dynamic motivational message based on progress
    private var motivationalMessage: String {
        let progress = goal.progressPercentage
        switch progress {
        case 0:
            return "Ready to lock in?"
        case 1..<25:
            return "Great start! Keep going!"
        case 25..<50:
            return "You're making progress!"
        case 50..<75:
            return "Halfway there!"
        case 75..<100:
            return "Almost there!"
        default:
            return "Goal completed!"
        }
    }

    private var motivationalIcon: String {
        let progress = goal.progressPercentage
        switch progress {
        case 0:
            return "target"
        case 1..<50:
            return "flame.fill"
        case 50..<100:
            return "bolt.fill"
        default:
            return "checkmark.circle.fill"
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Motivational Header
                    VStack(spacing: 20) {
                        // Icon and message
                        VStack(spacing: 12) {
                            Image(systemName: motivationalIcon)
                                .font(.system(size: 44))
                                .foregroundStyle(goal.isCompleted ? AnyShapeStyle(AppTheme.successGreen) : AnyShapeStyle(AppTheme.primaryGradient))

                            Text(motivationalMessage)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(.top, 8)

                        // Progress section
                        VStack(spacing: 12) {
                            // Hours text
                            HStack {
                                Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours)) hours")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)

                                Spacer()

                                Text("\(Int(goal.progressPercentage))%")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(goal.progressPercentage > 0 ? AppTheme.actionBlue : AppTheme.textSecondary)
                            }

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppTheme.borderLight)
                                        .frame(height: 12)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppTheme.progressGradient(for: goal.progressPercentage))
                                        .frame(width: max(0, geo.size.width * min(goal.progressPercentage / 100, 1.0)), height: 12)
                                        .animation(AppTheme.smoothAnimation, value: goal.progressPercentage)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // Primary CTA - Start Session
                    if !goal.isCompleted {
                        Button {
                            showingTimeLapseRecorder = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Start Session")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundColor(.white)
                            .background(AppTheme.primaryGradient)
                            .cornerRadius(16)
                            .shadow(color: AppTheme.actionBlue.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal)
                    }

                    // Subtasks Section
                    if !viewModel.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Subtasks")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Button {
                                    showingAddSubtask = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppTheme.primaryGradient)
                                }
                            }
                            .padding(.horizontal)

                            ForEach(viewModel.subtasks) { subtask in
                                Button {
                                    selectedSubtask = subtask
                                    showingTimeLapseRecorder = true
                                } label: {
                                    SubtaskCard(subtask: subtask)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent Sessions Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Sessions")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            if !viewModel.studySessions.isEmpty {
                                Text("\(viewModel.studySessions.count)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.actionBlue)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.studySessions.isEmpty {
                            // Friendly empty state
                            VStack(spacing: 16) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.primaryGradient)

                                VStack(spacing: 6) {
                                    Text("No sessions yet")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text("Start your first study session\nand it will appear here!")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            ForEach(viewModel.studySessions) { session in
                                NavigationLink(destination: VideoPlayerView(session: session)) {
                                    StudySessionCard(session: session, subtasks: viewModel.subtasks)
                                }
                            }
                        }
                    }

                    // Add subtask button if empty
                    if viewModel.subtasks.isEmpty {
                        Button {
                            showingAddSubtask = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                Text("Add subtasks to break down your goal")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(AppTheme.actionBlue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.actionBlue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingVideoPicker = true
                    } label: {
                        Label("Upload Video", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingAddSubtask = true
                    } label: {
                        Label("Add Subtask", systemImage: "checklist")
                    }

                    Divider()

                    Button {
                        Task {
                            try? await ConvexService.shared.archiveGoal(id: goal.id)
                            dismiss()
                        }
                    } label: {
                        Label("Archive Goal", systemImage: "archivebox")
                    }

                    Button(role: .destructive) {
                        Task {
                            try? await ConvexService.shared.deleteGoal(id: goal.id)
                            dismiss()
                        }
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.actionBlue)
                }
            }
        }
        .fullScreenCover(isPresented: $showingTimeLapseRecorder) {
            TimeLapseRecorderView(goalId: goal.id, subtaskId: selectedSubtask?.id)
        }
        .fullScreenCover(isPresented: $showingVideoPicker) {
            VideoRecorderView(goalId: goal.id, subtaskId: selectedSubtask?.id)
        }
        .sheet(isPresented: $showingAddSubtask) {
            AddSubtaskSheet(goalId: goal.id)
        }
        .onChange(of: showingTimeLapseRecorder) { _, isShowing in
            if !isShowing {
                selectedSubtask = nil
            }
        }
        .onChange(of: showingVideoPicker) { _, isShowing in
            if !isShowing {
                selectedSubtask = nil
            }
        }
    }
}

struct StudySessionCard: View {
    let session: StudySession
    let subtasks: [Subtask]

    @State private var thumbnail: UIImage?

    private var subtaskName: String? {
        guard let subtaskId = session.subtaskId else { return nil }
        return subtasks.first(where: { $0.id == subtaskId })?.title
    }

    var body: some View {
        HStack(spacing: 16) {
            // Video thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 80, height: 60)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }
            .onAppear {
                Task {
                    await loadThumbnail()
                }
            }

            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDuration)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                // Show subtask name if available
                if let subtaskName = subtaskName {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.caption)
                        Text(subtaskName)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.actionBlue)
                }

                Text(session.createdDate, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // Duration badge
            Text(String(format: "%.1fh", session.durationHours))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.primaryGradient)
                .cornerRadius(10)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func loadThumbnail() async {
        // Try to load cached thumbnail first
        if let thumbnailURL = session.thumbnailURL,
           FileManager.default.fileExists(atPath: thumbnailURL.path),
           let data = try? Data(contentsOf: thumbnailURL),
           let image = UIImage(data: data) {
            await MainActor.run {
                self.thumbnail = image
            }
            return
        }

        // Fallback: generate from video if no cached thumbnail
        guard let videoURL = session.videoURL,
              FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        do {
            let generatedThumbnail = try await VideoService.shared.generateThumbnail(from: videoURL)
            await MainActor.run {
                self.thumbnail = generatedThumbnail
            }
        } catch {
            print("Failed to generate thumbnail: \(error)")
        }
    }
}

// ViewModel for GoalDetailView
@MainActor
class GoalDetailViewModel: ObservableObject {
    @Published var studySessions: [StudySession] = []
    @Published var subtasks: [Subtask] = []

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared
    private let goalId: String

    init(goalId: String) {
        self.goalId = goalId
        subscribeToData()
    }

    private func subscribeToData() {
        // Subscribe to study sessions
        convexService.listStudySessions(goalId: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.studySessions = sessions
            }
            .store(in: &cancellables)

        // Subscribe to subtasks
        convexService.listSubtasks(goalId: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subtasks in
                self?.subtasks = subtasks
            }
            .store(in: &cancellables)
    }

    func deleteStudySessions(at indexSet: IndexSet) async {
        for index in indexSet {
            let session = studySessions[index]
            do {
                try await convexService.deleteStudySession(
                    id: session.id,
                    localVideoPath: session.localVideoPath,
                    localThumbnailPath: session.localThumbnailPath
                )
            } catch {
                print("Failed to delete study session: \(error)")
            }
        }
    }

    func deleteSubtasks(at indexSet: IndexSet) async {
        for index in indexSet {
            let subtask = subtasks[index]
            do {
                try await convexService.deleteSubtask(id: subtask.id)
            } catch {
                print("Failed to delete subtask: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        GoalDetailView(goal: Goal(
            _id: "1",
            title: "Learn Swift",
            description: "Master iOS development",
            targetHours: 30,
            completedHours: 15,
            status: .active,
            createdAt: Date().timeIntervalSince1970 * 1000
        ))
    }
}
