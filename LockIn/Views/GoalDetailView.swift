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

                    // Study Sessions List
                    if !viewModel.studySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Study Sessions")
                                .font(AppTheme.headlineFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal)

                            ForEach(viewModel.studySessions) { session in
                                NavigationLink(destination: VideoPlayerView(session: session)) {
                                    StudySessionCard(session: session)
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
            CameraRecorderView(goalId: goal.id, subtaskId: nil)
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoRecorderView(goalId: goal.id, subtaskId: nil)
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
