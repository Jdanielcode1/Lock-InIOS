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

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

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
        ScrollView {
            VStack(spacing: 20) {
                // Motivational Header
                motivationalHeader
                    .frame(maxWidth: sizing.maxContentWidth)

                // Primary CTA - Start Session
                if !goal.isCompleted {
                    startSessionButton
                        .frame(maxWidth: sizing.maxContentWidth)
                }

                // iPad: Side-by-side layout for subtasks and sessions
                if sizing.isIPad {
                    HStack(alignment: .top, spacing: sizing.cardSpacing) {
                        // Subtasks column
                        VStack(alignment: .leading, spacing: 12) {
                            subtasksSection
                        }
                        .frame(maxWidth: .infinity)

                        // Sessions column
                        VStack(alignment: .leading, spacing: 12) {
                            sessionsSection
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: sizing.maxContentWidth)
                    .padding(.horizontal, sizing.horizontalPadding)
                } else {
                    // iPhone: Vertical stack
                    subtasksSection
                    sessionsSection

                    // Add subtask button if empty
                    if viewModel.subtasks.isEmpty {
                        addSubtaskButton
                    }
                }
            }
            .padding(.vertical)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemGroupedBackground))
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

    // MARK: - Motivational Header
    private var motivationalHeader: some View {
        VStack(spacing: 16) {
            // Icon and message
            VStack(spacing: 8) {
                Image(systemName: motivationalIcon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(goal.isCompleted ? .green : .accentColor)

                Text(motivationalMessage)
                    .font(.title3.bold())
            }
            .padding(.top, 4)

            // Progress section
            VStack(spacing: 8) {
                // Hours text
                HStack {
                    Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours)) hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(goal.progressPercentage))%")
                        .font(.headline)
                        .foregroundStyle(goal.progressPercentage > 0 ? .primary : .secondary)
                }

                // Native progress bar
                ProgressView(value: goal.progressPercentage, total: 100)
                    .tint(goal.isCompleted ? .green : .accentColor)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, sizing.horizontalPadding)
    }

    // MARK: - Start Session Button
    private var startSessionButton: some View {
        Button {
            showingTimeLapseRecorder = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Start Session")
            }
            .appleFilledButton()
        }
        .padding(.horizontal, sizing.horizontalPadding)
    }

    // MARK: - Subtasks Section
    @ViewBuilder
    private var subtasksSection: some View {
        if !viewModel.subtasks.isEmpty || sizing.isIPad {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Subtasks")
                        .font(.headline)

                    Spacer()

                    Button {
                        showingAddSubtask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, sizing.isIPad ? 0 : 16)

                if viewModel.subtasks.isEmpty {
                    // Empty state for iPad
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No subtasks yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Add Subtask") {
                            showingAddSubtask = true
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, sizing.isIPad ? 0 : 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.subtasks.enumerated()), id: \.element.id) { index, subtask in
                            Button {
                                selectedSubtask = subtask
                                showingTimeLapseRecorder = true
                            } label: {
                                SubtaskCard(subtask: subtask)
                            }
                            .buttonStyle(.plain)

                            if index < viewModel.subtasks.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, sizing.isIPad ? 0 : 16)
                }
            }
        }
    }

    // MARK: - Sessions Section
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)

                Spacer()

                if !viewModel.studySessions.isEmpty {
                    Text("\(viewModel.studySessions.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, sizing.isIPad ? 0 : 16)

            if viewModel.studySessions.isEmpty {
                // Friendly empty state
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Text("No sessions yet")
                            .font(.subheadline.bold())

                        Text("Start your first study session\nand it will appear here!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, sizing.isIPad ? 0 : 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.studySessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink(destination: VideoPlayerView(session: session)) {
                            StudySessionCard(session: session, subtasks: viewModel.subtasks, isIPad: sizing.isIPad)
                        }

                        if index < viewModel.studySessions.count - 1 {
                            Divider()
                                .padding(.leading, 96)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, sizing.isIPad ? 0 : 16)
            }
        }
    }

    // MARK: - Add Subtask Button
    private var addSubtaskButton: some View {
        Button {
            showingAddSubtask = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text("Add subtasks to break down your goal")
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

struct StudySessionCard: View {
    let session: StudySession
    let subtasks: [Subtask]
    var isIPad: Bool = false

    @State private var thumbnail: UIImage?

    private var subtaskName: String? {
        guard let subtaskId = session.subtaskId else { return nil }
        return subtasks.first(where: { $0.id == subtaskId })?.title
    }

    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 60)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .onAppear {
                Task {
                    await loadThumbnail()
                }
            }

            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.formattedDuration)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                // Show subtask name if available
                if let subtaskName = subtaskName {
                    Label(subtaskName, systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                Text(session.createdDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration badge
            Text(String(format: "%.1fh", session.durationHours))
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
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
