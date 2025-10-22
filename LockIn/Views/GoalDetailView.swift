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
    @State private var showingVideoRecorder = false
    @State private var showingVideoPicker = false
    @State private var showingAddSubtask = false
    @State private var selectedSubtask: Subtask?

    init(goal: Goal) {
        self.goal = goal
        _viewModel = StateObject(wrappedValue: GoalDetailViewModel(goalId: goal.id))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Progress Header
                    VStack(spacing: 16) {
                        // Large progress ring
                        ZStack {
                            Circle()
                                .stroke(AppTheme.lightPurple.opacity(0.2), lineWidth: 20)
                                .frame(width: 200, height: 200)

                            Circle()
                                .trim(from: 0, to: goal.progressPercentage / 100)
                                .stroke(
                                    AppTheme.progressGradient(for: goal.progressPercentage),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(AppTheme.smoothAnimation, value: goal.progressPercentage)

                            VStack(spacing: 4) {
                                Text("\(Int(goal.progressPercentage))%")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("\(Int(goal.completedHours))/\(Int(goal.targetHours)) hrs")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(.top, 20)

                        // Goal info
                        VStack(spacing: 8) {
                            Text(goal.title)
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(goal.description)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Stats
                        HStack(spacing: 20) {
                            StatCard(
                                icon: "clock.fill",
                                value: "\(Int(goal.hoursRemaining))",
                                label: "Hours Left",
                                color: AppTheme.primaryYellow
                            )

                            StatCard(
                                icon: "video.fill",
                                value: "\(viewModel.studySessions.count)",
                                label: "Sessions",
                                color: AppTheme.primaryRed
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .playfulCard()
                    .padding(.horizontal)

                    // Add Study Session Buttons
                    HStack(spacing: 12) {
                        // Record Button
                        Button {
                            showingVideoRecorder = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.title2)
                                Text("Record")
                                    .font(AppTheme.captionFont)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .background(AppTheme.primaryGradient)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.smallCornerRadius)
                        .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Upload Button
                        Button {
                            showingVideoPicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                Text("Upload")
                                    .font(AppTheme.captionFont)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .background(AppTheme.energyGradient)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.smallCornerRadius)
                        .shadow(color: AppTheme.primaryRed.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)

                    // Subtasks Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Subtasks")
                                .font(AppTheme.headlineFont)
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            Button {
                                showingAddSubtask = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                }
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.primaryGradient)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.subtasks.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))

                                Text("No subtasks yet")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textSecondary)

                                Text("Break down your goal into smaller tasks")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .playfulCard()
                            .padding(.horizontal)
                        } else {
                            ForEach(viewModel.subtasks) { subtask in
                                Button {
                                    selectedSubtask = subtask
                                    showingVideoRecorder = true
                                } label: {
                                    SubtaskCard(subtask: subtask)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                            .onDelete { indexSet in
                                Task {
                                    await viewModel.deleteSubtasks(at: indexSet)
                                }
                            }
                        }
                    }

                    // Study Sessions List
                    if !viewModel.studySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Study Sessions")
                                .font(AppTheme.headlineFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal)

                            ForEach(viewModel.studySessions) { session in
                                NavigationLink(destination: VideoPlayerView(session: session)) {
                                    StudySessionCard(session: session, subtasks: viewModel.subtasks)
                                }
                            }
                            .onDelete { indexSet in
                                Task {
                                    await viewModel.deleteStudySessions(at: indexSet)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVideoRecorder) {
            CameraRecorderView(goalId: goal.id, subtaskId: selectedSubtask?.id)
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoRecorderView(goalId: goal.id, subtaskId: selectedSubtask?.id)
        }
        .sheet(isPresented: $showingAddSubtask) {
            AddSubtaskSheet(goalId: goal.id)
        }
        .onChange(of: showingVideoRecorder) { isShowing in
            if !isShowing {
                selectedSubtask = nil
            }
        }
        .onChange(of: showingVideoPicker) { isShowing in
            if !isShowing {
                selectedSubtask = nil
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .playfulCard()
    }
}

struct StudySessionCard: View {
    let session: StudySession
    let subtasks: [Subtask]

    private var subtaskName: String? {
        guard let subtaskId = session.subtaskId else { return nil }
        return subtasks.first(where: { $0.id == subtaskId })?.title
    }

    var body: some View {
        HStack(spacing: 16) {
            // Video thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 80, height: 60)

                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }

            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDuration)
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)

                // Show subtask name if available
                if let subtaskName = subtaskName {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.caption)
                        Text(subtaskName)
                            .font(AppTheme.captionFont)
                    }
                    .foregroundStyle(AppTheme.energyGradient)
                }

                Text(session.uploadedDate, style: .date)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // Duration badge
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text(String(format: "%.1fh", session.durationHours))
                    .font(AppTheme.captionFont)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.energyGradient)
            .cornerRadius(12)
        }
        .padding()
        .playfulCard()
        .padding(.horizontal)
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
                try await convexService.deleteStudySession(id: session.id)
            } catch {
                print("❌ Failed to delete study session: \(error)")
            }
        }
    }

    func deleteSubtasks(at indexSet: IndexSet) async {
        for index in indexSet {
            let subtask = subtasks[index]
            do {
                try await convexService.deleteSubtask(id: subtask.id)
            } catch {
                print("❌ Failed to delete subtask: \(error)")
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
