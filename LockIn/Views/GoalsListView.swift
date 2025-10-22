//
//  GoalsListView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct GoalsListView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var showingCreateGoal = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.primaryPurple)
                } else if viewModel.goals.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(viewModel.goals) { goal in
                                NavigationLink(destination: GoalDetailView(goal: goal)) {
                                    GoalCard(goal: goal)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteGoal(goal)
                                        }
                                    } label: {
                                        Label("Delete Goal", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Lock In")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                CreateGoalView(viewModel: viewModel)
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
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
                    .stroke(AppTheme.lightPurple.opacity(0.3), lineWidth: 8)
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
                    .foregroundColor(AppTheme.primaryYellow)

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
