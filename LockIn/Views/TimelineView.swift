//
//  TimelineView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI
import Combine

enum TimelineMode: String, CaseIterable {
    case goals = "Goals"
    case todos = "Todos"
}

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedMode: TimelineMode = .goals
    @State private var selectedTodoForPlayback: TodoItem?

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
                    Picker("", selection: $selectedMode) {
                        ForEach(TimelineMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Content based on selection
                    if selectedMode == .goals {
                        goalsTimeline
                    } else {
                        todosTimeline
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .fullScreenCover(item: $selectedTodoForPlayback) { todo in
                if let videoURL = todo.videoURL {
                    TodoVideoPlayerView(videoURL: videoURL, todo: todo)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Goals Timeline

    var goalsTimeline: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.actionBlue)
                    Spacer()
                }
            } else if viewModel.sessionsByDate.isEmpty {
                VStack {
                    Spacer()
                    emptyState
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: sizing.sectionSpacing, pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.sortedDates, id: \.self) { date in
                            Section {
                                if sizing.isIPad {
                                    // iPad: Grid layout within each section
                                    LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                                        ForEach(viewModel.sessionsByDate[date] ?? []) { item in
                                            NavigationLink(destination: VideoPlayerView(session: item.session)) {
                                                TimelineCard(item: item)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                } else {
                                    // iPhone: Vertical stack
                                    ForEach(viewModel.sessionsByDate[date] ?? []) { item in
                                        NavigationLink(destination: VideoPlayerView(session: item.session)) {
                                            TimelineCard(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            } header: {
                                DateHeader(date: date)
                            }
                        }
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - Todos Timeline

    var todosTimeline: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.actionBlue)
                    Spacer()
                }
            } else if viewModel.todosByDate.isEmpty {
                VStack {
                    Spacer()
                    todoEmptyState
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: sizing.sectionSpacing, pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.sortedTodoDates, id: \.self) { date in
                            Section {
                                if sizing.isIPad {
                                    // iPad: Grid layout within each section
                                    LazyVGrid(columns: sizing.gridItems(count: sizing.gridColumns, spacing: sizing.cardSpacing), spacing: sizing.cardSpacing) {
                                        ForEach(viewModel.todosByDate[date] ?? []) { todo in
                                            Button {
                                                if todo.hasVideo {
                                                    selectedTodoForPlayback = todo
                                                }
                                            } label: {
                                                TodoTimelineCard(todo: todo)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                } else {
                                    // iPhone: Vertical stack
                                    ForEach(viewModel.todosByDate[date] ?? []) { todo in
                                        Button {
                                            if todo.hasVideo {
                                                selectedTodoForPlayback = todo
                                            }
                                        } label: {
                                            TodoTimelineCard(todo: todo)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            } header: {
                                DateHeader(date: date)
                            }
                        }
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("No Study Sessions Yet")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("Start a timelapse recording to\ntrack your study sessions")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    var todoEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("No Completed Todos Yet")
                .font(AppTheme.titleFont)
                .foregroundColor(AppTheme.textPrimary)

            Text("Complete todos to see them\nin your timeline")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DateHeader: View {
    let date: Date

    var body: some View {
        HStack {
            Text(formatDate(date))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(AppTheme.background)
    }

    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

struct TimelineCard: View {
    let item: TimelineItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 80, height: 60)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }
            .onAppear {
                loadThumbnail()
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.goalTitle)
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(item.session.formattedDuration, systemImage: "clock.fill")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                    Label(formatTime(item.session.createdDate), systemImage: "calendar")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Duration badge
            Text(String(format: "%.1fh", item.session.durationHours))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.energyGradient)
                .clipShape(Capsule())
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func loadThumbnail() {
        Task {
            if let thumbnailURL = item.session.thumbnailURL,
               FileManager.default.fileExists(atPath: thumbnailURL.path),
               let data = try? Data(contentsOf: thumbnailURL),
               let image = UIImage(data: data) {
                await MainActor.run { thumbnail = image }
                return
            }

            if let videoURL = item.session.videoURL,
               FileManager.default.fileExists(atPath: videoURL.path) {
                if let generated = try? await VideoService.shared.generateThumbnail(from: videoURL) {
                    await MainActor.run { thumbnail = generated }
                }
            }
        }
    }
}

struct TodoTimelineCard: View {
    let todo: TodoItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(todo.isCompleted ? AnyShapeStyle(AppTheme.successGreen.opacity(0.3)) : AnyShapeStyle(AppTheme.primaryGradient.opacity(0.3)))
                    .frame(width: 80, height: 60)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                } else {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(todo.isCompleted ? AppTheme.successGreen : AppTheme.textSecondary)
                }
            }
            .onAppear {
                loadThumbnail()
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(AppTheme.headlineFont)
                    .foregroundColor(todo.isCompleted ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(formatTime(todo.createdDate), systemImage: "calendar")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                    if todo.hasVideo {
                        Label("Video", systemImage: "video.fill")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.actionBlue)
                    }
                }
            }

            Spacer()

            // Status badge
            if todo.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.successGreen)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func loadThumbnail() {
        guard let thumbnailURL = todo.thumbnailURL,
              FileManager.default.fileExists(atPath: thumbnailURL.path),
              let data = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: data) else {
            return
        }
        thumbnail = image
    }
}

// MARK: - ViewModel

struct TimelineItem: Identifiable {
    let id: String
    let session: StudySession
    let goalTitle: String

    init(session: StudySession, goalTitle: String) {
        self.id = session.id
        self.session = session
        self.goalTitle = goalTitle
    }
}

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var sessionsByDate: [Date: [TimelineItem]] = [:]
    @Published var todosByDate: [Date: [TodoItem]] = [:]
    @Published var isLoading = true

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    var sortedDates: [Date] {
        sessionsByDate.keys.sorted(by: >)
    }

    var sortedTodoDates: [Date] {
        todosByDate.keys.sorted(by: >)
    }

    init() {
        loadData()
    }

    private func loadData() {
        // Subscribe to goals first
        convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.loadSessionsForGoals(goals)
            }
            .store(in: &cancellables)

        // Subscribe to todos
        convexService.listTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] todos in
                self?.updateTodos(todos)
            }
            .store(in: &cancellables)
    }

    private func updateTodos(_ todos: [TodoItem]) {
        let calendar = Calendar.current

        // Group todos by date (only completed ones for timeline)
        var newTodosByDate: [Date: [TodoItem]] = [:]

        for todo in todos.filter({ $0.isCompleted }) {
            let dateKey = calendar.startOfDay(for: todo.createdDate)

            if newTodosByDate[dateKey] == nil {
                newTodosByDate[dateKey] = []
            }
            newTodosByDate[dateKey]?.append(todo)
        }

        // Sort todos within each date (newest first)
        for (date, items) in newTodosByDate {
            newTodosByDate[date] = items.sorted { $0.createdDate > $1.createdDate }
        }

        todosByDate = newTodosByDate
    }

    private func loadSessionsForGoals(_ goals: [Goal]) {
        // Clear existing subscriptions for sessions
        let goalDict = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.title) })

        // For each goal, subscribe to its sessions
        for goal in goals {
            convexService.listStudySessions(goalId: goal.id)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    self?.updateSessions(sessions, goalTitle: goal.title, goalDict: goalDict)
                }
                .store(in: &cancellables)
        }

        isLoading = false
    }

    private func updateSessions(_ sessions: [StudySession], goalTitle: String, goalDict: [String: String]) {
        let calendar = Calendar.current

        // Create timeline items
        let items = sessions.map { TimelineItem(session: $0, goalTitle: goalTitle) }

        // Group by date
        var newSessionsByDate: [Date: [TimelineItem]] = sessionsByDate

        for item in items {
            let dateKey = calendar.startOfDay(for: item.session.createdDate)

            if newSessionsByDate[dateKey] == nil {
                newSessionsByDate[dateKey] = []
            }

            // Remove existing item with same ID and add updated one
            newSessionsByDate[dateKey]?.removeAll { $0.id == item.id }
            newSessionsByDate[dateKey]?.append(item)
        }

        // Sort items within each date
        for (date, items) in newSessionsByDate {
            newSessionsByDate[date] = items.sorted { $0.session.createdDate > $1.session.createdDate }
        }

        sessionsByDate = newSessionsByDate
    }
}

#Preview {
    TimelineView()
}
