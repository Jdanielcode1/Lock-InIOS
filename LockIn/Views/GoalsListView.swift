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
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented control
                    Picker("", selection: $listMode) {
                        ForEach(ListMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Content based on selection
                    if listMode == .goals {
                        goalsContent
                    } else {
                        todosContent
                    }
                }
            }
            .navigationTitle(listMode == .goals ? "Goals" : "To Do")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                        .tint(AppTheme.primaryPurple)
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
                // iPhone: List layout (unchanged)
                List {
                    ForEach(goalsViewModel.goals) { goal in
                        NavigationLink(destination: GoalDetailView(goal: goal)) {
                            GoalCardHorizontal(goal: goal)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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

                    // Bottom spacer for tab bar
                    Color.clear
                        .frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    var goalsEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("No Goals Yet")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("Create your first goal to start\ntracking your study sessions!")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateGoal = true
            } label: {
                Text("Create Goal")
                    .font(AppTheme.headlineFont)
                    .primaryButton()
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Todos Content

    // Get incomplete todos
    private var incompleteTodos: [TodoItem] {
        todoViewModel.todos.filter { !$0.isCompleted }
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

    var todosContent: some View {
        Group {
            if todoViewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primaryPurple)
                    Spacer()
                }
            } else if todoViewModel.todos.isEmpty {
                todosEmptyStateView
            } else if sizing.isIPad {
                // iPad: Grid layout
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                            ForEach(todoViewModel.todos) { todo in
                                todoGridItem(todo: todo)
                            }
                        }
                        .padding(.horizontal, sizing.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, !incompleteTodos.isEmpty ? 180 : 100)
                    }

                    // Sticky Start Session button (iPad - centered and constrained)
                    if !incompleteTodos.isEmpty {
                        startSessionButton
                            .frame(maxWidth: 500)
                    }
                }
            } else {
                // iPhone: List layout (unchanged)
                ZStack(alignment: .bottom) {
                    List {
                        ForEach(todoViewModel.todos) { todo in
                            HStack(spacing: 12) {
                                // Selection circle for session (only for incomplete todos)
                                if !todo.isCompleted {
                                    Button {
                                        toggleTodoSelection(todo.id)
                                    } label: {
                                        Image(systemName: selectedTodoIdsForSession.contains(todo.id)
                                            ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedTodoIdsForSession.contains(todo.id)
                                                ? AppTheme.actionBlue : AppTheme.textSecondary.opacity(0.4))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Todo card
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
                                .buttonStyle(PlainButtonStyle())
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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

                        // Bottom spacer for tab bar and sticky button
                        Color.clear
                            .frame(height: !incompleteTodos.isEmpty ? 160 : 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

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
                                ? AppTheme.actionBlue : AppTheme.textSecondary.opacity(0.4))
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

    // MARK: - Start Session Button
    private var startSessionButton: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [AppTheme.background.opacity(0), AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: 8) {
                // Selection count label
                if !selectedTodoIdsForSession.isEmpty {
                    Text("\(selectedTodoIdsForSession.count) task\(selectedTodoIdsForSession.count == 1 ? "" : "s") selected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Start Session button
                Button {
                    showTodoSessionRecorder = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(selectedTodoIdsForSession.isEmpty
                            ? "Start Session"
                            : "Start Session (\(selectedTodoIdsForSession.count))")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundColor(.white)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.actionBlue.opacity(0.4), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for tab bar
            .background(AppTheme.background)
        }
    }

    var todosEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("No To-Dos Yet")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("Add tasks and complete them\nby recording a video!")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingCreateTodo = true
            } label: {
                Text("Add To-Do")
                    .font(AppTheme.headlineFont)
                    .primaryButton()
            }

            Spacer()
        }
        .padding()
    }
}

struct GoalCardHorizontal: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 16) {
            // Left: Title and hours
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)

                Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours)) hours")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.borderLight)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.progressGradient(for: goal.progressPercentage))
                            .frame(width: max(0, geo.size.width * min(goal.progressPercentage / 100, 1.0)), height: 6)
                            .animation(AppTheme.smoothAnimation, value: goal.progressPercentage)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // Right: Percentage or completed badge
            if goal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.successGreen)
            } else {
                Text("\(Int(goal.progressPercentage))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(goal.progressPercentage > 0 ? AppTheme.actionBlue : AppTheme.textSecondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// Keep old card for potential grid view
struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(goal.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)

            Spacer()

            HStack {
                Text("\(Int(goal.completedHours)) of \(Int(goal.targetHours))h")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Text("\(Int(goal.progressPercentage))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(goal.progressPercentage > 0 ? AppTheme.actionBlue : AppTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.borderLight)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.progressGradient(for: goal.progressPercentage))
                        .frame(width: geo.size.width * min(goal.progressPercentage / 100, 1.0), height: 8)
                        .animation(AppTheme.smoothAnimation, value: goal.progressPercentage)
                }
            }
            .frame(height: 8)

            if goal.isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.successGreen)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .playfulCard()
    }
}

#Preview {
    GoalsListView()
}
