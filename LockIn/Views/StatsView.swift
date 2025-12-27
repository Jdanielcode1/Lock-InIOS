//
//  StatsView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI
import Combine

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero stat
                        heroCard

                        // Quick stats grid
                        statsGrid

                        // Weekly chart
                        weeklyChart

                        // Goals breakdown
                        goalsBreakdown
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    var heroCard: some View {
        VStack(spacing: 16) {
            Text("Total Study Time")
                .font(AppTheme.bodyFont)
                .foregroundColor(.white.opacity(0.8))

            Text(viewModel.formattedTotalHours)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 24) {
                HeroStat(value: "\(viewModel.totalSessions)", label: "Sessions")
                HeroStat(value: "\(viewModel.activeGoals)", label: "Active Goals")
                HeroStat(value: "\(viewModel.completedGoals)", label: "Completed")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal)
        .background(AppTheme.primaryGradient)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.actionBlue.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatBox(
                icon: "flame.fill",
                value: "\(viewModel.currentStreak)",
                label: "Day Streak",
                color: .orange
            )

            StatBox(
                icon: "clock.fill",
                value: String(format: "%.1f", viewModel.avgSessionLength),
                label: "Avg Session (min)",
                color: AppTheme.actionBlue
            )

            StatBox(
                icon: "calendar",
                value: String(format: "%.1f", viewModel.hoursThisWeek),
                label: "Hours This Week",
                color: AppTheme.actionBlue
            )

            StatBox(
                icon: "star.fill",
                value: String(format: "%.0f%%", viewModel.completionRate),
                label: "Completion Rate",
                color: AppTheme.successGreen
            )
        }
    }

    var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyData, id: \.day) { data in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(data.hours > 0 ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(Color.gray.opacity(0.2)))
                            .frame(width: 36, height: max(8, CGFloat(data.hours) * 20))

                        Text(data.day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120, alignment: .bottom)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    var goalsBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goals Progress")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            if viewModel.goals.isEmpty {
                Text("No goals yet")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(viewModel.goals) { goal in
                    GoalProgressRow(goal: goal)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct HeroStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct GoalProgressRow: View {
    let goal: Goal

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(goal.completedHours))/\(Int(goal.targetHours))h")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.progressGradient(for: goal.progressPercentage))
                        .frame(width: geo.size.width * min(goal.progressPercentage / 100, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

struct WeeklyData {
    let day: String
    let hours: Double
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var totalHours: Double = 0
    @Published var totalSessions: Int = 0
    @Published var currentStreak: Int = 0
    @Published var avgSessionLength: Double = 0
    @Published var hoursThisWeek: Double = 0
    @Published var weeklyData: [WeeklyData] = []

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    var formattedTotalHours: String {
        String(format: "%.1fh", totalHours)
    }

    var activeGoals: Int {
        goals.filter { $0.status == .active }.count
    }

    var completedGoals: Int {
        goals.filter { $0.status == .completed }.count
    }

    var completionRate: Double {
        guard !goals.isEmpty else { return 0 }
        return Double(completedGoals) / Double(goals.count) * 100
    }

    init() {
        loadData()
        generateWeeklyData()
    }

    private func loadData() {
        convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.goals = goals
                self?.calculateStats(from: goals)
            }
            .store(in: &cancellables)
    }

    private func calculateStats(from goals: [Goal]) {
        totalHours = goals.reduce(0) { $0 + $1.completedHours }

        // Load sessions for each goal to get total count
        for goal in goals {
            convexService.listStudySessions(goalId: goal.id)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    guard let self = self else { return }
                    self.totalSessions = sessions.count

                    if !sessions.isEmpty {
                        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
                        self.avgSessionLength = totalMinutes / Double(sessions.count)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func generateWeeklyData() {
        let calendar = Calendar.current
        let today = Date()
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        var data: [WeeklyData] = []

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let weekday = calendar.component(.weekday, from: date) - 1
                // Placeholder - would need actual session data per day
                let hours = Double.random(in: 0...3)
                data.append(WeeklyData(day: weekdays[weekday], hours: hours))
            }
        }

        weeklyData = data
        hoursThisWeek = data.reduce(0) { $0 + $1.hours }
    }
}

#Preview {
    StatsView()
}
