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
    let onStartSession: (String, String?, [GoalTodo]) -> Void

    @StateObject private var viewModel: GoalDetailViewModel
    @State private var showingVideoPicker = false
    @State private var showingAddGoalTodo = false
    @State private var recentlyArchivedTodo: GoalTodo?
    @State private var showUndoToast = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @EnvironmentObject private var videoPlayerSession: VideoPlayerSessionManager
    @EnvironmentObject private var recordingSession: RecordingSessionManager

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    // Use reactive goal from viewModel, falling back to initial goal
    private var goal: Goal {
        viewModel.goal ?? initialGoal
    }

    // Detect if goal was deleted (viewModel.goal becomes nil after initial subscription)
    private var isGoalDeleted: Bool {
        viewModel.goal == nil && viewModel.hasReceivedInitialData
    }

    init(goal: Goal, onStartSession: @escaping (String, String?, [GoalTodo]) -> Void) {
        self.initialGoal = goal
        self.onStartSession = onStartSession
        _viewModel = StateObject(wrappedValue: GoalDetailViewModel(goalId: goal.id, initialGoal: goal))
    }

    // Dynamic motivational message based on progress
    private var motivationalMessage: String {
        let progress = goal.progressPercentage
        if goal.isCompleted {
            return "Goal completed!"
        } else if progress == 0 {
            return "Ready to start?"
        } else if progress < 25 {
            return "Great start!"
        } else if progress < 50 {
            return "Making progress!"
        } else if progress < 75 {
            return "Halfway there!"
        } else {
            return "Almost done!"
        }
    }

    var body: some View {
        List {
            // Progress Section
            Section {
                progressHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Start Session Button
            if !goal.isCompleted {
                Section {
                    Button {
                        onStartSession(
                            goal.id,
                            nil,
                            viewModel.goalTodos.filter { !$0.isCompleted }
                        )
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Session", systemImage: "play.fill")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.accentGreen)
                    .foregroundStyle(.white)
                }
            }

            // Tasks Section
            Section {
                if viewModel.goalTodos.isEmpty {
                    tasksEmptyState
                } else {
                    ForEach(viewModel.goalTodos) { todo in
                        GoalTodoRow(
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
                                if todo.hasVideo, let videoURL = todo.videoURL {
                                    videoPlayerSession.playGoalTodoVideo(goalTodo: todo, videoURL: videoURL) {
                                        // Build continue data to resume/append to existing video
                                        let continueData = ContinueRecordingData(
                                            videoURL: videoURL,
                                            speedSegmentsJSON: nil,  // GoalTodo doesn't store speed segments
                                            duration: (todo.videoDurationMinutes ?? 0) * 60,  // Convert to seconds
                                            notes: todo.videoNotes
                                        )
                                        recordingSession.startGoalTodoRecording(goalTodo: todo, continueFrom: continueData)
                                    }
                                } else {
                                    onStartSession(
                                        goal.id,
                                        todo.id,
                                        viewModel.goalTodos.filter { !$0.isCompleted }
                                    )
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    // Archive first, then hard delete after undo window
                                    try? await ConvexService.shared.archiveGoalTodo(id: todo.id)

                                    // Show toast with undo
                                    ToastManager.shared.showDeleted(
                                        "Task",
                                        undoAction: {
                                            Task { try? await ConvexService.shared.unarchiveGoalTodo(id: todo.id) }
                                        },
                                        hardDeleteAction: {
                                            Task { try? await ConvexService.shared.deleteGoalTodo(id: todo.id) }
                                        }
                                    )
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                recentlyArchivedTodo = todo
                                Task {
                                    try? await ConvexService.shared.archiveGoalTodo(id: todo.id)
                                    await MainActor.run {
                                        withAnimation(.spring(response: 0.3)) {
                                            showUndoToast = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                            withAnimation(.spring(response: 0.3)) {
                                                showUndoToast = false
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task {
                                    try? await ConvexService.shared.toggleGoalTodo(
                                        id: todo.id,
                                        isCompleted: !todo.isCompleted
                                    )
                                }
                            } label: {
                                Label(
                                    todo.isCompleted ? "Undo" : "Done",
                                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark"
                                )
                            }
                            .tint(todo.isCompleted ? .orange : .green)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Tasks")
                    Spacer()
                    Button {
                        showingAddGoalTodo = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.medium))
                    }
                }
            }

            // Recent Sessions Section
            Section {
                if viewModel.isLoadingSessions && viewModel.studySessions.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if viewModel.studySessions.isEmpty {
                    sessionsEmptyState
                } else {
                    ForEach(viewModel.studySessions) { session in
                        Button {
                            videoPlayerSession.playStudySession(session) {
                                // onResume: Build continue data to resume/append to existing video
                                if let videoURL = session.videoURL {
                                    let continueData = ContinueRecordingData(
                                        videoURL: videoURL,
                                        speedSegmentsJSON: nil,  // Study sessions don't store speed segments
                                        duration: session.durationMinutes * 60,  // Convert to seconds
                                        notes: session.notes
                                    )
                                    recordingSession.startGoalSession(
                                        goalId: goal.id,
                                        goalTodoId: session.goalTodoId,
                                        availableTodos: viewModel.goalTodos.filter { !$0.isCompleted },
                                        continueFrom: continueData
                                    )
                                } else {
                                    // Fallback: start fresh session if video URL unavailable
                                    recordingSession.startGoalSession(
                                        goalId: goal.id,
                                        goalTodoId: session.goalTodoId,
                                        availableTodos: viewModel.goalTodos.filter { !$0.isCompleted }
                                    )
                                }
                            }
                        } label: {
                            SessionRow(session: session, goalTodos: viewModel.goalTodos)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.canLoadMoreSessions {
                        Button {
                            Task { await viewModel.loadMoreSessions() }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingSessions {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Load More")
                                }
                                Spacer()
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("Recent Sessions")
                    Spacer()
                    if !viewModel.studySessions.isEmpty {
                        Text("\(viewModel.studySessions.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { tabBarVisibility.hide() }
        .onDisappear { tabBarVisibility.show() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddGoalTodo = true
                    } label: {
                        Label("Add Task", systemImage: "checklist")
                    }

                    Button {
                        showingVideoPicker = true
                    } label: {
                        Label("Upload Video", systemImage: "square.and.arrow.up")
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
                            // Archive first, then hard delete after undo window
                            try? await ConvexService.shared.archiveGoal(id: goal.id)
                            dismiss()

                            // Show toast with undo, hard delete after 4 seconds
                            ToastManager.shared.showDeleted(
                                "Goal",
                                undoAction: {
                                    Task { try? await ConvexService.shared.unarchiveGoal(id: goal.id) }
                                },
                                hardDeleteAction: {
                                    Task { try? await ConvexService.shared.deleteGoal(id: goal.id) }
                                }
                            )
                        }
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoPicker) {
            VideoRecorderView(goalId: goal.id, goalTodoId: nil)
        }
        .sheet(isPresented: $showingAddGoalTodo) {
            AddGoalTodoSheet(goalId: goal.id)
        }
        .task {
            try? await ConvexService.shared.checkAndResetRecurringTodos(goalId: goal.id)
        }
        .onChange(of: isGoalDeleted) { _, deleted in
            if deleted {
                // Goal was deleted (e.g., from another device or via sync)
                ToastManager.shared.showDeleted("Goal")
                dismiss()
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoToast, let archivedTodo = recentlyArchivedTodo {
                undoToast(for: archivedTodo)
            }
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Editable Title
            editableTitleView
                .padding(.top, 8)

            // Circular Progress Ring
            CircularProgressRing(
                progress: goal.progressPercentage,
                completedHours: goal.completedHours,
                targetHours: goal.targetHours,
                isCompleted: goal.isCompleted
            )

            // Motivational message
            Text(motivationalMessage)
                .font(.headline)
                .foregroundStyle(goal.isCompleted ? .green : .primary)

            // Stats row
            HStack(spacing: 32) {
                StatItem(
                    value: goal.completedHours.formattedDurationCompact,
                    label: "Completed"
                )

                StatItem(
                    value: goal.hoursRemaining.formattedDurationCompact,
                    label: "Remaining"
                )

                StatItem(
                    value: "\(viewModel.studySessions.count)",
                    label: "Sessions"
                )
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Editable Title
    @ViewBuilder
    private var editableTitleView: some View {
        if isEditingTitle {
            TextField("Goal title", text: $editedTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit(saveTitle)
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused {
                        saveTitle()
                    }
                }
                .padding(.horizontal, 16)
        } else {
            HStack(spacing: 6) {
                Text(goal.title)
                    .font(.title.bold())

                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                editedTitle = goal.title
                isEditingTitle = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFocused = true
                }
            }
        }
    }

    private func saveTitle() {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingTitle = false

        guard !trimmedTitle.isEmpty, trimmedTitle != goal.title else { return }

        Task {
            try? await ConvexService.shared.updateGoalTitle(id: goal.id, title: trimmedTitle)
        }
    }

    // MARK: - Empty States
    private var tasksEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)

            Text("No tasks yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingAddGoalTodo = true
            } label: {
                Text("Add Task")
                    .font(.subheadline.bold())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var sessionsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No sessions yet")
                    .font(.subheadline.bold())

                Text("Record yourself studying to track progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Undo Toast
    private func undoToast(for todo: GoalTodo) -> some View {
        HStack(spacing: 12) {
            Text("\"\(todo.title)\" archived")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button {
                Task {
                    try? await ConvexService.shared.unarchiveGoalTodo(id: todo.id)
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3)) {
                            showUndoToast = false
                        }
                    }
                }
            } label: {
                Text("Undo")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Goal Todo Row (Native iOS Style)
struct GoalTodoRow: View {
    let todo: GoalTodo
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(todo.isCompleted ? .green : Color(UIColor.tertiaryLabel))
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .strikethrough(todo.isCompleted)

                    HStack(spacing: 8) {
                        // Recurring badge
                        if todo.isRecurring {
                            Label(todo.frequency.displayName, systemImage: todo.frequency.icon)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        // Hours progress for hours-based todos
                        if todo.todoType == .hours, let estimated = todo.estimatedHours {
                            let completed = todo.completedHours ?? 0
                            Text(completed.formattedProgressCompact(of: estimated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Video indicator
                if todo.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !todo.isCompleted {
                    Image(systemName: "video.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: StudySession
    let goalTodos: [GoalTodo]

    @State private var thumbnail: UIImage?

    private var goalTodoName: String? {
        guard let todoId = session.goalTodoId else { return nil }
        return goalTodos.first(where: { $0.id == todoId })?.title
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 64, height: 48)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Image(systemName: "play.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .onAppear {
                Task { await loadThumbnail() }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.durationHours.formattedDuration)
                    .font(.subheadline.bold())

                if let todoName = goalTodoName {
                    Text(todoName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(session.createdDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func loadThumbnail() async {
        if let thumbnailURL = session.thumbnailURL {
            if let image = await ThumbnailCache.shared.thumbnail(for: thumbnailURL) {
                await MainActor.run { self.thumbnail = image }
                return
            }
        }

        guard let videoURL = session.videoURL,
              FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        do {
            let generatedThumbnail = try await VideoService.shared.generateThumbnail(from: videoURL)
            await MainActor.run { self.thumbnail = generatedThumbnail }
        } catch {
            print("Failed to generate thumbnail: \(error)")
        }
    }
}

// MARK: - ViewModel
@MainActor
class GoalDetailViewModel: ObservableObject {
    @Published var goal: Goal?
    @Published var studySessions: [StudySession] = []
    @Published var goalTodos: [GoalTodo] = []
    @Published var isLoadingSessions = false
    @Published var canLoadMoreSessions = true
    @Published var hasReceivedInitialData = false

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared
    private let goalId: String
    private var sessionsCursor: String?

    init(goalId: String, initialGoal: Goal) {
        self.goalId = goalId
        self.goal = initialGoal
        subscribeToData()
    }

    private func subscribeToData() {
        convexService.subscribeToGoal(id: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goal in
                self?.hasReceivedInitialData = true
                self?.goal = goal  // Will be nil if deleted
            }
            .store(in: &cancellables)

        convexService.listGoalTodos(goalId: goalId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.goalTodos = todos
            }
            .store(in: &cancellables)

        Task { await loadMoreSessions() }
    }

    func loadMoreSessions() async {
        guard !isLoadingSessions && canLoadMoreSessions else { return }

        isLoadingSessions = true
        defer { isLoadingSessions = false }

        do {
            let result = try await convexService.listStudySessionsPaginated(
                goalId: goalId,
                cursor: sessionsCursor,
                numItems: 10
            )

            for session in result.page {
                if !studySessions.contains(where: { $0.id == session.id }) {
                    studySessions.append(session)
                }
            }

            sessionsCursor = result.continueCursor
            canLoadMoreSessions = !result.isDone
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    func refreshSessions() async {
        sessionsCursor = nil
        canLoadMoreSessions = true
        studySessions = []
        await loadMoreSessions()
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
                studySessions.removeAll { $0.id == session.id }
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
        GoalDetailView(
            goal: Goal(
                _id: "1",
                title: "Learn Swift",
                description: "Master iOS development",
                targetHours: 30,
                completedHours: 15,
                status: .active,
                createdAt: Date().timeIntervalSince1970 * 1000
            ),
            onStartSession: { _, _, _ in }
        )
        .environmentObject(TabBarVisibility())
    }
}
