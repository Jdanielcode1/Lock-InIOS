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

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: sizing.sectionSpacing) {
                        // Hero stat
                        heroCard

                        // Quick stats grid
                        statsGrid

                        // Weekly chart
                        weeklyChart

                        // Goals breakdown
                        goalsBreakdown

                        // Todos section
                        todosSection
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.vertical)
                    .padding(.bottom, 100)
                    .frame(maxWidth: sizing.maxContentWidth)
                    .frame(maxWidth: .infinity) // Center on iPad
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
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
                HeroStat(value: "\(viewModel.currentStreak)", label: "Day Streak")
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
        LazyVGrid(columns: sizing.gridItems(count: sizing.statsGridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
            StatBox(
                icon: "flame.fill",
                value: "\(viewModel.currentStreak)",
                label: "Day Streak",
                color: .orange
            )

            StatBox(
                icon: "calendar",
                value: viewModel.formattedHoursThisWeek,
                label: viewModel.weeklyTrendLabel,
                color: AppTheme.actionBlue
            )

            StatBox(
                icon: "star.fill",
                value: viewModel.bestDay,
                label: "Best Day",
                color: AppTheme.warningAmber
            )

            StatBox(
                icon: "checkmark.circle.fill",
                value: "\(viewModel.completedGoals)",
                label: "Goals Done",
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
                            .frame(width: 36, height: max(8, CGFloat(data.hours) * 30))

                        Text(data.day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(data.isToday ? AppTheme.actionBlue : AppTheme.textSecondary)
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

    var todosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Todos")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            if viewModel.todos.isEmpty {
                Text("No todos yet")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 16) {
                    // Streak
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 24))
                            Text("\(viewModel.todoStreak)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        Text("Day Streak")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    // This week with trend
                    VStack(spacing: 8) {
                        Text("\(viewModel.todosThisWeek)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.successGreen)

                        HStack(spacing: 4) {
                            Text("This Week")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)

                            if viewModel.todoWeeklyTrend != 0 {
                                Text(viewModel.todoWeeklyTrend > 0 ? "↑\(viewModel.todoWeeklyTrend)" : "↓\(abs(viewModel.todoWeeklyTrend))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(viewModel.todoWeeklyTrend > 0 ? AppTheme.successGreen : .orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
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

struct WeeklyData: Identifiable {
    let id = UUID()
    let day: String
    let hours: Double
    let isToday: Bool
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var sessions: [StudySession] = []
    @Published var totalHours: Double = 0
    @Published var totalSessions: Int = 0
    @Published var currentStreak: Int = 0
    @Published var hoursThisWeek: Double = 0
    @Published var hoursLastWeek: Double = 0
    @Published var weeklyData: [WeeklyData] = []
    @Published var bestDay: String = "-"

    // Todo stats
    @Published var todos: [TodoItem] = []
    @Published var todoStreak: Int = 0
    @Published var todosThisWeek: Int = 0
    @Published var todosLastWeek: Int = 0

    var todoWeeklyTrend: Int {
        todosThisWeek - todosLastWeek
    }

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    var formattedTotalHours: String {
        String(format: "%.1fh", totalHours)
    }

    var formattedHoursThisWeek: String {
        String(format: "%.1fh", hoursThisWeek)
    }

    var activeGoals: Int {
        goals.filter { $0.status == .active }.count
    }

    var completedGoals: Int {
        goals.filter { $0.status == .completed }.count
    }

    var weeklyTrendLabel: String {
        if hoursLastWeek == 0 {
            return "This Week"
        }
        let change = ((hoursThisWeek - hoursLastWeek) / hoursLastWeek) * 100
        if change >= 0 {
            return "This Week +\(Int(change))%"
        } else {
            return "This Week \(Int(change))%"
        }
    }

    init() {
        loadData()
    }

    private func loadData() {
        // Load goals
        convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.goals = goals
                self?.totalHours = goals.reduce(0) { $0 + $1.completedHours }
            }
            .store(in: &cancellables)

        // Load ALL sessions for stats
        convexService.listAllStudySessions()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessions = sessions
                self?.calculateAllStats(from: sessions)
            }
            .store(in: &cancellables)

        // Load todos for stats
        convexService.listTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.todos = todos
                self?.calculateTodoStats(from: todos)
            }
            .store(in: &cancellables)
    }

    private func calculateTodoStats(from todos: [TodoItem]) {
        let completedTodos = todos.filter { $0.isCompleted }

        // Calculate streak (consecutive days with at least 1 completion)
        todoStreak = calculateTodoStreak(from: completedTodos)

        // Calculate weekly counts
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? today

        var thisWeekCount = 0
        var lastWeekCount = 0

        for todo in completedTodos {
            let todoDate = Date(timeIntervalSince1970: todo.createdAt / 1000)
            if todoDate >= thisWeekStart {
                thisWeekCount += 1
            } else if todoDate >= lastWeekStart && todoDate < thisWeekStart {
                lastWeekCount += 1
            }
        }

        todosThisWeek = thisWeekCount
        todosLastWeek = lastWeekCount
    }

    private func calculateTodoStreak(from completedTodos: [TodoItem]) -> Int {
        guard !completedTodos.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique days with completed todos
        var daysWithCompletions = Set<Date>()
        for todo in completedTodos {
            let todoDate = Date(timeIntervalSince1970: todo.createdAt / 1000)
            let dayStart = calendar.startOfDay(for: todoDate)
            daysWithCompletions.insert(dayStart)
        }

        // Count consecutive days from today backwards
        var streak = 0
        var checkDate = today

        // Check if today has a completion, if not start from yesterday
        if !daysWithCompletions.contains(today) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
                if !daysWithCompletions.contains(yesterday) {
                    return 0
                }
            }
        }

        // Count consecutive days
        while daysWithCompletions.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    private func calculateAllStats(from sessions: [StudySession]) {
        // Total sessions
        totalSessions = sessions.count

        // Calculate streak
        currentStreak = calculateStreak(from: sessions)

        // Calculate weekly data
        calculateWeeklyData(from: sessions)

        // Calculate best day
        calculateBestDay(from: sessions)
    }

    private func calculateStreak(from sessions: [StudySession]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique days with sessions
        var daysWithSessions = Set<Date>()
        for session in sessions {
            let sessionDate = Date(timeIntervalSince1970: session.createdAt / 1000)
            let dayStart = calendar.startOfDay(for: sessionDate)
            daysWithSessions.insert(dayStart)
        }

        // Count consecutive days from today backwards
        var streak = 0
        var checkDate = today

        // Check if today has a session, if not start from yesterday
        if !daysWithSessions.contains(today) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
                // If yesterday also has no session, streak is 0
                if !daysWithSessions.contains(yesterday) {
                    return 0
                }
            }
        }

        // Count consecutive days
        while daysWithSessions.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    private func calculateWeeklyData(from sessions: [StudySession]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Get start of this week and last week
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? today

        var thisWeekHours: Double = 0
        var lastWeekHours: Double = 0
        var dailyHours: [Date: Double] = [:]

        for session in sessions {
            let sessionDate = Date(timeIntervalSince1970: session.createdAt / 1000)
            let dayStart = calendar.startOfDay(for: sessionDate)
            let hours = session.durationMinutes / 60

            // Accumulate daily hours
            dailyHours[dayStart, default: 0] += hours

            // Calculate this week vs last week
            if sessionDate >= thisWeekStart {
                thisWeekHours += hours
            } else if sessionDate >= lastWeekStart && sessionDate < thisWeekStart {
                lastWeekHours += hours
            }
        }

        hoursThisWeek = thisWeekHours
        hoursLastWeek = lastWeekHours

        // Build weekly data for chart (last 7 days)
        var data: [WeeklyData] = []
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                let weekday = calendar.component(.weekday, from: date) - 1
                let hours = dailyHours[dayStart] ?? 0
                let isToday = i == 0
                data.append(WeeklyData(day: weekdays[weekday], hours: hours, isToday: isToday))
            }
        }

        weeklyData = data
    }

    private func calculateBestDay(from sessions: [StudySession]) {
        guard !sessions.isEmpty else {
            bestDay = "-"
            return
        }

        let calendar = Calendar.current
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var hoursByWeekday: [Int: Double] = [:]

        for session in sessions {
            let sessionDate = Date(timeIntervalSince1970: session.createdAt / 1000)
            let weekday = calendar.component(.weekday, from: sessionDate) - 1
            hoursByWeekday[weekday, default: 0] += session.durationMinutes / 60
        }

        if let (bestWeekday, _) = hoursByWeekday.max(by: { $0.value < $1.value }) {
            bestDay = weekdays[bestWeekday]
        } else {
            bestDay = "-"
        }
    }
}

#Preview {
    StatsView()
}
