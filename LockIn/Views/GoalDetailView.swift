//
//  GoalDetailView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import Combine

struct GoalDetailView: View {
    private let initialGoal: Goal

    @StateObject private var viewModel: GoalDetailViewModel
    @State private var showingVideoPicker = false
    @State private var showingTimeLapseRecorder = false
    @State private var showingAddGoalTodo = false
    @State private var selectedGoalTodo: GoalTodo?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    // Use reactive goal from viewModel, falling back to initial goal
    private var goal: Goal {
        viewModel.goal ?? initialGoal
    }

    init(goal: Goal) {
        self.initialGoal = goal
        _viewModel = StateObject(wrappedValue: GoalDetailViewModel(goalId: goal.id, initialGoal: goal))
    }

    // Dynamic motivational message based on progress
    private var motivationalMessage: String {
        let progress = goal.progressPercentage
        if goal.isCompleted {
            return "Goal completed!"
        } else if progress == 0 {
            return "Ready to lock in?"
        } else if progress < 25 {
            return "Great start! Keep going!"
        } else if progress < 50 {
            return "You're making progress!"
        } else if progress < 75 {
            return "Halfway there!"
        } else {
            return "Almost there!"
        }
    }

    private var motivationalIcon: String {
        let progress = goal.progressPercentage
        if goal.isCompleted {
            return "checkmark.circle.fill"
        } else if progress == 0 {
            return "target"
        } else if progress < 50 {
            return "flame.fill"
        } else {
            return "bolt.fill"
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

                // iPad: Side-by-side layout for tasks and sessions
                if sizing.isIPad {
                    HStack(alignment: .top, spacing: sizing.cardSpacing) {
                        // Tasks column
                        VStack(alignment: .leading, spacing: 12) {
                            goalTodosSection
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
                    goalTodosSection
                    sessionsSection

                    // Add task button if empty
                    if viewModel.goalTodos.isEmpty {
                        addGoalTodoButton
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
        .onAppear { tabBarVisibility.hide() }
        .onDisappear { tabBarVisibility.show() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingVideoPicker = true
                    } label: {
                        Label("Upload Video", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingAddGoalTodo = true
                    } label: {
                        Label("Add Task", systemImage: "checklist")
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
            TimeLapseRecorderView(goalId: goal.id, goalTodoId: selectedGoalTodo?.id)
        }
        .fullScreenCover(isPresented: $showingVideoPicker) {
            VideoRecorderView(goalId: goal.id, goalTodoId: selectedGoalTodo?.id)
        }
        .sheet(isPresented: $showingAddGoalTodo) {
            AddGoalTodoSheet(goalId: goal.id)
        }
        .onChange(of: showingTimeLapseRecorder) { _, isShowing in
            if !isShowing {
                selectedGoalTodo = nil
            }
        }
        .onChange(of: showingVideoPicker) { _, isShowing in
            if !isShowing {
                selectedGoalTodo = nil
            }
        }
        .task {
            // Check and reset recurring todos on view appear
            try? await ConvexService.shared.checkAndResetRecurringTodos(goalId: goal.id)
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
                    Text(goal.completedHours.formattedProgress(of: goal.targetHours))
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

    // MARK: - Goal Todos Section
    @ViewBuilder
    private var goalTodosSection: some View {
        if !viewModel.goalTodos.isEmpty || sizing.isIPad {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tasks")
                        .font(.headline)

                    Spacer()

                    Button {
                        showingAddGoalTodo = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, sizing.isIPad ? 0 : 16)

                if viewModel.goalTodos.isEmpty {
                    // Empty state for iPad
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No tasks yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Add Task") {
                            showingAddGoalTodo = true
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
                        ForEach(Array(viewModel.goalTodos.enumerated()), id: \.element.id) { index, todo in
                            GoalTodoCard(
                                todo: todo,
                                onToggle: {
                                    Task {
                                        try? await ConvexService.shared.toggleGoalTodo(
                                            id: todo.id,
                                            isCompleted: !todo.isCompleted
                                        )
                                    }
                                },
                                onTap: {
                                    selectedGoalTodo = todo
                                    showingTimeLapseRecorder = true
                                }
                            )

                            if index < viewModel.goalTodos.count - 1 {
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
                            StudySessionCard(session: session, goalTodos: viewModel.goalTodos, isIPad: sizing.isIPad)
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

    // MARK: - Add Goal Todo Button
    private var addGoalTodoButton: some View {
        Button {
            showingAddGoalTodo = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text("Add tasks to break down your goal")
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
    let goalTodos: [GoalTodo]
    var isIPad: Bool = false

    @State private var thumbnail: UIImage?

    private var goalTodoName: String? {
        guard let todoId = session.goalTodoId else { return nil }
        return goalTodos.first(where: { $0.id == todoId })?.title
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

                // Show goal todo name if available
                if let todoName = goalTodoName {
                    Label(todoName, systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                Text(session.createdDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration badge
            Text(session.durationHours.formattedDurationCompact)
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
    @Published var goal: Goal?
    @Published var studySessions: [StudySession] = []
    @Published var goalTodos: [GoalTodo] = []

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared
    private let goalId: String

    init(goalId: String, initialGoal: Goal) {
        self.goalId = goalId
        self.goal = initialGoal
        subscribeToData()
    }

    private func subscribeToData() {
        // Subscribe to goal updates
        convexService.subscribeToGoal(id: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goal in
                if let goal = goal {
                    self?.goal = goal
                }
            }
            .store(in: &cancellables)

        // Subscribe to study sessions
        convexService.listStudySessions(goalId: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.studySessions = sessions
            }
            .store(in: &cancellables)

        // Subscribe to goal todos
        convexService.listGoalTodos(goalId: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.goalTodos = todos
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

    func deleteGoalTodos(at indexSet: IndexSet) async {
        for index in indexSet {
            let todo = goalTodos[index]
            do {
                try await convexService.deleteGoalTodo(id: todo.id)
            } catch {
                print("Failed to delete goal todo: \(error)")
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
