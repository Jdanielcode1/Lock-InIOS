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
        }
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(goalsViewModel.goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalCardHorizontal(goal: goal)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button {
                                    Task {
                                        await goalsViewModel.archiveGoal(goal)
                                    }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await goalsViewModel.deleteGoal(goal)
                                    }
                                } label: {
                                    Label("Delete Goal", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(todoViewModel.todos) { todo in
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
                            .contextMenu {
                                if !todo.hasVideo {
                                    Button {
                                        selectedTodoForRecording = todo
                                    } label: {
                                        Label("Record Video", systemImage: "video.badge.plus")
                                    }
                                }

                                Button {
                                    Task {
                                        await todoViewModel.toggleTodo(todo)
                                    }
                                } label: {
                                    Label(
                                        todo.isCompleted ? "Mark Incomplete" : "Mark Complete",
                                        systemImage: todo.isCompleted ? "circle" : "checkmark.circle"
                                    )
                                }

                                Button {
                                    Task {
                                        await todoViewModel.archiveTodo(todo)
                                    }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await todoViewModel.deleteTodo(todo)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100) // Space for floating tab bar
                }
            }
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
