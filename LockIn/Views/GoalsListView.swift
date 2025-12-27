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
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(goalsViewModel.goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalCard(goal: goal)
                            }
                            .contextMenu {
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
                    .padding()
                    .padding(.bottom, 100) // Space for floating tab bar
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

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(AppTheme.borderLight, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: goal.progressPercentage / 100)
                    .stroke(
                        AppTheme.progressGradient(for: goal.progressPercentage),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(AppTheme.smoothAnimation, value: goal.progressPercentage)

                VStack(spacing: 2) {
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)

            // Goal title
            Text(goal.title)
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Hours info
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.actionBlue)

                Text("\(Int(goal.completedHours))/\(Int(goal.targetHours))h")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Status badge
            if goal.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completed")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.successGradient)
                .cornerRadius(12)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .playfulCard()
    }
}

#Preview {
    GoalsListView()
}
