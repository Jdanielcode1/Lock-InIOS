//
//  GoalsListView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

enum ListMode: String, CaseIterable {
    case todos = "To Do"
    case goals = "Goals"
}

struct GoalsListView: View {
    @StateObject private var goalsViewModel = GoalsViewModel()
    @StateObject private var todoViewModel = TodoViewModel()
    @State private var showingCreateGoal = false
    @State private var showingCreateTodo = false
    @State private var listMode: ListMode = .goals
    @State private var selectedTodoForRecording: TodoItem?
    @State private var showingVideoPlayer = false
    @State private var selectedTodoForPlayback: TodoItem?

    // Goal todo recording/playback
    @State private var selectedGoalTodoForRecording: GoalTodo?
    @State private var selectedGoalTodoForPlayback: GoalTodo?
    @State private var showingGoalTodoRecorder = false

    // Multi-select for todo sessions
    @State private var selectedTodoIdsForSession: Set<String> = []
    @State private var showTodoSessionRecorder = false

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $listMode) {
                    ForEach(ListMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Content based on selection
                if listMode == .goals {
                    goalsContent
                } else {
                    todosContent
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(listMode == .goals ? "Goals" : "To Do")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCreateGoal) {
                CreateGoalView(viewModel: goalsViewModel)
            }
            .sheet(isPresented: $showingCreateTodo) {
                AddTodoSheet(viewModel: todoViewModel)
            }
            .fullScreenCover(item: $selectedTodoForRecording) { todo in
                TodoRecorderView(todo: todo, viewModel: todoViewModel)
            }
            .fullScreenCover(item: $selectedTodoForPlayback) { todo in
                if let videoURL = todo.videoURL {
                    TodoVideoPlayerView(videoURL: videoURL, todo: todo)
                }
            }
            .fullScreenCover(isPresented: $showTodoSessionRecorder) {
                TodoSessionRecorderView(
                    selectedTodoIds: selectedTodoIdsForSession,
                    viewModel: todoViewModel,
                    onDismiss: {
                        selectedTodoIdsForSession.removeAll()
                    }
                )
            }
            .fullScreenCover(isPresented: $showingGoalTodoRecorder) {
                if let goalTodo = selectedGoalTodoForRecording {
                    TimeLapseRecorderView(goalId: goalTodo.goalId, goalTodoId: goalTodo.id)
                }
            }
            .fullScreenCover(item: $selectedGoalTodoForPlayback) { goalTodo in
                if let videoURL = goalTodo.videoURL {
                    GoalTodoVideoPlayerView(videoURL: videoURL, goalTodo: goalTodo)
                }
            }
            .onChange(of: showingGoalTodoRecorder) { _, isShowing in
                if !isShowing {
                    selectedGoalTodoForRecording = nil
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Goals Content

    var goalsContent: some View {
        Group {
            if goalsViewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if goalsViewModel.goals.isEmpty {
                goalsEmptyStateView
            } else if sizing.isIPad {
                // iPad: Grid layout
                ScrollView {
                    LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                        ForEach(goalsViewModel.goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalCard(goal: goal)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button {
                                    Task { await goalsViewModel.archiveGoal(goal) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                Button(role: .destructive) {
                                    Task { await goalsViewModel.deleteGoal(goal) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            } else {
                // iPhone: Native insetGrouped list
                List {
                    ForEach(goalsViewModel.goals) { goal in
                        NavigationLink(destination: GoalDetailView(goal: goal)) {
                            GoalCardHorizontal(goal: goal)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task {
                                    await goalsViewModel.archiveGoal(goal)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await goalsViewModel.deleteGoal(goal)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    var goalsEmptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            Text("No Goals Yet")
                .font(.title2.bold())

            Text("Create your first goal to start\ntracking your study sessions!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateGoal = true
            } label: {
                Text("Create Goal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Todos Content

    // Get incomplete todos
    private var incompleteTodos: [TodoItem] {
        todoViewModel.todos.filter { !$0.isCompleted }
    }

    // Get incomplete goal todos
    private var incompleteGoalTodos: [GoalTodo] {
        todoViewModel.goalTodos.filter { !$0.isCompleted }
    }

    // Check if there are any incomplete tasks (for showing start session button)
    private var hasIncompleteTasks: Bool {
        !incompleteTodos.isEmpty || !incompleteGoalTodos.isEmpty
    }

    // Get the first incomplete todo that doesn't have a video yet
    private var nextTodoToRecord: TodoItem? {
        todoViewModel.todos.first { !$0.isCompleted && !$0.hasVideo }
    }

    private func toggleTodoSelection(_ todoId: String) {
        if selectedTodoIdsForSession.contains(todoId) {
            selectedTodoIdsForSession.remove(todoId)
        } else {
            selectedTodoIdsForSession.insert(todoId)
        }
    }

    // Check if all lists are empty
    private var allTodosEmpty: Bool {
        todoViewModel.todos.isEmpty && todoViewModel.goalTodos.isEmpty
    }

    var todosContent: some View {
        Group {
            if todoViewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if allTodosEmpty {
                todosEmptyStateView
            } else if sizing.isIPad {
                // iPad: Grid layout
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Regular Todos
                            if !todoViewModel.todos.isEmpty {
                                LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                                    ForEach(todoViewModel.todos) { todo in
                                        todoGridItem(todo: todo)
                                    }
                                }
                            }

                            // Goal Todos Section
                            if !todoViewModel.goalTodos.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("From Goals")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)

                                    LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                                        ForEach(todoViewModel.goalTodos) { goalTodo in
                                            goalTodoGridItem(goalTodo: goalTodo)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, sizing.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, hasIncompleteTasks ? 180 : 100)
                    }

                    // Sticky Start Session button (iPad - centered and constrained)
                    if !incompleteTodos.isEmpty {
                        startSessionButton
                            .frame(maxWidth: 500)
                    }
                }
            } else {
                // iPhone: Native insetGrouped list
                ZStack(alignment: .bottom) {
                    List {
                        // Regular Todos Section
                        if !todoViewModel.todos.isEmpty {
                            Section {
                                ForEach(todoViewModel.todos) { todo in
                                    HStack(spacing: 12) {
                                        // Selection circle for session (only for incomplete todos)
                                        if !todo.isCompleted {
                                            Button {
                                                toggleTodoSelection(todo.id)
                                            } label: {
                                                Image(systemName: selectedTodoIdsForSession.contains(todo.id)
                                                    ? "checkmark.circle.fill" : "circle")
                                                    .font(.title2)
                                                    .foregroundStyle(selectedTodoIdsForSession.contains(todo.id)
                                                        ? Color.accentColor : Color(UIColor.tertiaryLabel))
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        // Todo card
                                        TodoCard(
                                            todo: todo,
                                            onToggle: {
                                                Task {
                                                    await todoViewModel.toggleTodo(todo)
                                                }
                                            },
                                            onTap: {
                                                if todo.hasVideo {
                                                    selectedTodoForPlayback = todo
                                                } else {
                                                    selectedTodoForRecording = todo
                                                }
                                            }
                                        )
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            Task {
                                                await todoViewModel.archiveTodo(todo)
                                            }
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                        .tint(.purple)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                await todoViewModel.deleteTodo(todo)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            Task {
                                                await todoViewModel.toggleTodo(todo)
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
                        }

                        // Goal Todos Section
                        if !todoViewModel.goalTodos.isEmpty {
                            Section(header: Text("From Goals")) {
                                ForEach(todoViewModel.goalTodos) { goalTodo in
                                    GoalTodoListRow(
                                        goalTodo: goalTodo,
                                        onToggle: {
                                            Task {
                                                await todoViewModel.toggleGoalTodo(goalTodo)
                                            }
                                        },
                                        onTap: {
                                            if goalTodo.hasVideo {
                                                selectedGoalTodoForPlayback = goalTodo
                                            } else {
                                                selectedGoalTodoForRecording = goalTodo
                                                showingGoalTodoRecorder = true
                                            }
                                        }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                await todoViewModel.deleteGoalTodo(goalTodo)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            Task {
                                                await todoViewModel.toggleGoalTodo(goalTodo)
                                            }
                                        } label: {
                                            Label(
                                                goalTodo.isCompleted ? "Undo" : "Done",
                                                systemImage: goalTodo.isCompleted ? "arrow.uturn.backward" : "checkmark"
                                            )
                                        }
                                        .tint(goalTodo.isCompleted ? .orange : .green)
                                    }
                                }
                            }
                        }

                        // Bottom spacer for sticky button
                        if !incompleteTodos.isEmpty {
                            Color.clear
                                .frame(height: 100)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)

                    // Sticky Start Session button (iPhone)
                    if !incompleteTodos.isEmpty {
                        startSessionButton
                    }
                }
            }
        }
    }

    // MARK: - iPad Todo Grid Item
    @ViewBuilder
    private func todoGridItem(todo: TodoItem) -> some View {
        VStack(spacing: 0) {
            // Selection overlay for incomplete todos
            if !todo.isCompleted {
                HStack {
                    Spacer()
                    Button {
                        toggleTodoSelection(todo.id)
                    } label: {
                        Image(systemName: selectedTodoIdsForSession.contains(todo.id)
                            ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(selectedTodoIdsForSession.contains(todo.id)
                                ? Color.accentColor : .secondary.opacity(0.4))
                            .padding(8)
                    }
                }
            }

            Button {
                if todo.hasVideo {
                    selectedTodoForPlayback = todo
                } else {
                    selectedTodoForRecording = todo
                }
            } label: {
                TodoCard(
                    todo: todo,
                    onToggle: {
                        Task { await todoViewModel.toggleTodo(todo) }
                    },
                    onTap: {
                        if todo.hasVideo {
                            selectedTodoForPlayback = todo
                        } else {
                            selectedTodoForRecording = todo
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contextMenu {
            Button {
                Task { await todoViewModel.toggleTodo(todo) }
            } label: {
                Label(todo.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            Button {
                Task { await todoViewModel.archiveTodo(todo) }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                Task { await todoViewModel.deleteTodo(todo) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - iPad Goal Todo Grid Item
    @ViewBuilder
    private func goalTodoGridItem(goalTodo: GoalTodo) -> some View {
        GoalTodoCard(
            todo: goalTodo,
            onToggle: {
                Task { await todoViewModel.toggleGoalTodo(goalTodo) }
            },
            onTap: {
                if goalTodo.hasVideo {
                    selectedGoalTodoForPlayback = goalTodo
                } else {
                    selectedGoalTodoForRecording = goalTodo
                    showingGoalTodoRecorder = true
                }
            }
        )
        .contextMenu {
            Button {
                Task { await todoViewModel.toggleGoalTodo(goalTodo) }
            } label: {
                Label(goalTodo.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: goalTodo.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            Button(role: .destructive) {
                Task { await todoViewModel.deleteGoalTodo(goalTodo) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Start Session Button
    private var startSessionButton: some View {
        VStack(spacing: 8) {
            // Selection count label
            if !selectedTodoIdsForSession.isEmpty {
                Text("\(selectedTodoIdsForSession.count) task\(selectedTodoIdsForSession.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Start Session button
            Button {
                showTodoSessionRecorder = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                    Text(selectedTodoIdsForSession.isEmpty
                        ? "Start Session"
                        : "Start Session (\(selectedTodoIdsForSession.count))")
                }
                .appleFilledButton()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Space for tab bar
        .background(
            Color(UIColor.systemGroupedBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
                .mask(Rectangle().padding(.top, -20))
        )
    }

    var todosEmptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            Text("No To-Dos Yet")
                .font(.title2.bold())

            Text("Add tasks and complete them\nby recording a video!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateTodo = true
            } label: {
                Text("Add To-Do")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

struct GoalCardHorizontal: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 16) {
            // Left: Title and hours with progress
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(Int(goal.completedHours))/\(Int(goal.targetHours)) hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Native progress bar
                ProgressView(value: goal.progressPercentage, total: 100)
                    .tint(goal.isCompleted ? .green : .accentColor)
            }

            Spacer()

            // Right: Percentage or completed badge
            if goal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(goal.progressPercentage))%")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// iPad grid card
struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(goal.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)

            Spacer()

            HStack {
                Text("\(Int(goal.completedHours))/\(Int(goal.targetHours)) hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: goal.progressPercentage, total: 100)
                .tint(goal.isCompleted ? .green : .accentColor)
        }
        .padding(16)
        .frame(minHeight: 130)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// iPhone list row for goal todos
struct GoalTodoListRow: View {
    let goalTodo: GoalTodo
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox button
                Button(action: onToggle) {
                    Image(systemName: goalTodo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(goalTodo.isCompleted ? .green : Color(UIColor.tertiaryLabel))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    // Title with strikethrough if completed
                    Text(goalTodo.title)
                        .font(.body)
                        .foregroundStyle(goalTodo.isCompleted ? .secondary : .primary)
                        .strikethrough(goalTodo.isCompleted)

                    HStack(spacing: 6) {
                        // Goal name badge
                        if let goalTitle = goalTodo.goalTitle {
                            Text(goalTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(UIColor.tertiarySystemFill))
                                .cornerRadius(4)
                        }

                        // Recurring badge
                        if goalTodo.isRecurring {
                            HStack(spacing: 2) {
                                Image(systemName: goalTodo.frequency.icon)
                                Text(goalTodo.frequency.displayName)
                            }
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        }

                        // Hours progress for hours-based todos
                        if goalTodo.todoType == .hours, let estimated = goalTodo.estimatedHours {
                            let completed = goalTodo.completedHours ?? 0
                            Text("\(String(format: "%.1f", completed))/\(String(format: "%.1f", estimated))h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Video indicator or record prompt
                Image(systemName: goalTodo.hasVideo ? "video.fill" : "video.badge.plus")
                    .font(.caption)
                    .foregroundStyle(goalTodo.hasVideo ? .green : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GoalsListView()
}
