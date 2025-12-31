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
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedMode) {
                    ForEach(TimelineMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Content based on selection
                if selectedMode == .goals {
                    goalsTimeline
                } else {
                    todosTimeline
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
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
            if viewModel.isLoading && viewModel.sessionsByDate.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
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
                    LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.sortedDates, id: \.self) { date in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array((viewModel.sessionsByDate[date] ?? []).enumerated()), id: \.element.id) { index, item in
                                        NavigationLink(destination: VideoPlayerView(session: item.session)) {
                                            TimelineCard(item: item)
                                        }
                                        .buttonStyle(.plain)

                                        if index < (viewModel.sessionsByDate[date]?.count ?? 0) - 1 {
                                            Divider()
                                                .padding(.leading, 96)
                                        }
                                    }
                                }
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            } header: {
                                DateHeader(date: date)
                            }
                        }

                        // Load more indicator
                        if viewModel.canLoadMoreSessions {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await viewModel.loadMoreSessions() }
                                }
                        }
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }

    // MARK: - Todos Timeline

    var todosTimeline: some View {
        Group {
            if viewModel.isLoadingMoreTodos && viewModel.todosByDate.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
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
                    LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.sortedTodoDates, id: \.self) { date in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array((viewModel.todosByDate[date] ?? []).enumerated()), id: \.element.id) { index, todo in
                                        Button {
                                            if todo.hasVideo {
                                                selectedTodoForPlayback = todo
                                            }
                                        } label: {
                                            TodoTimelineCard(todo: todo)
                                        }
                                        .buttonStyle(.plain)

                                        if index < (viewModel.todosByDate[date]?.count ?? 0) - 1 {
                                            Divider()
                                                .padding(.leading, 96)
                                        }
                                    }
                                }
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            } header: {
                                DateHeader(date: date)
                            }
                        }

                        // Load more indicator
                        if viewModel.canLoadMoreTodos {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await viewModel.loadMoreTodos() }
                                }
                        }
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text("No Study Sessions Yet")
                .font(.title3.bold())

            Text("Start a timelapse recording to\ntrack your study sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    var todoEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text("No Completed Todos Yet")
                .font(.title3.bold())

            Text("Complete todos to see them\nin your timeline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.systemGroupedBackground))
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
        HStack(spacing: 12) {
            // Thumbnail
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

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .onAppear {
                loadThumbnail()
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.goalTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(item.session.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(formatTime(item.session.createdDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Duration
            Text(item.session.durationHours.formattedDurationCompact)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
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
        HStack(spacing: 12) {
            // Thumbnail or placeholder
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

                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                } else {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(todo.isCompleted ? .green : .secondary)
                }
            }
            .onAppear {
                loadThumbnail()
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(todo.isCompleted ? .primary : .secondary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(formatTime(todo.createdDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if todo.hasVideo {
                        Label("Video", systemImage: "video.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            Spacer()

            // Status
            if todo.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
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
    @Published var isLoadingMoreSessions = false
    @Published var isLoadingMoreTodos = false
    @Published var canLoadMoreSessions = true
    @Published var canLoadMoreTodos = true

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared
    private var goals: [Goal] = []
    private var sessionsCursor: String?
    private var todosCursor: String?

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
        // Subscribe to goals for title lookup
        convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.goals = goals
                // Load initial sessions after getting goals
                if self?.sessionsByDate.isEmpty == true {
                    Task { await self?.loadMoreSessions() }
                }
            }
            .store(in: &cancellables)

        // Load initial todos
        Task { await loadMoreTodos() }
    }

    func loadMoreSessions() async {
        guard !isLoadingMoreSessions && canLoadMoreSessions else { return }

        isLoadingMoreSessions = true
        defer { isLoadingMoreSessions = false; isLoading = false }

        do {
            let result = try await convexService.listAllStudySessionsPaginated(
                cursor: sessionsCursor,
                numItems: 20
            )

            let calendar = Calendar.current
            let goalDict = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.title) })

            // Create timeline items with goal titles
            let items = result.page.map { session in
                let goalTitle = goalDict[session.goalId] ?? "Unknown Goal"
                return TimelineItem(session: session, goalTitle: goalTitle)
            }

            // Group by date
            for item in items {
                let dateKey = calendar.startOfDay(for: item.session.createdDate)

                if sessionsByDate[dateKey] == nil {
                    sessionsByDate[dateKey] = []
                }

                // Avoid duplicates
                if !sessionsByDate[dateKey]!.contains(where: { $0.id == item.id }) {
                    sessionsByDate[dateKey]?.append(item)
                }
            }

            // Sort items within each date
            for (date, items) in sessionsByDate {
                sessionsByDate[date] = items.sorted { $0.session.createdDate > $1.session.createdDate }
            }

            sessionsCursor = result.continueCursor
            canLoadMoreSessions = !result.isDone
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    func loadMoreTodos() async {
        guard !isLoadingMoreTodos && canLoadMoreTodos else { return }

        isLoadingMoreTodos = true
        defer { isLoadingMoreTodos = false }

        do {
            let result = try await convexService.listCompletedTodosPaginated(
                cursor: todosCursor,
                numItems: 20
            )

            let calendar = Calendar.current

            // Group by date
            for todo in result.page {
                let dateKey = calendar.startOfDay(for: todo.createdDate)

                if todosByDate[dateKey] == nil {
                    todosByDate[dateKey] = []
                }

                // Avoid duplicates
                if !todosByDate[dateKey]!.contains(where: { $0.id == todo.id }) {
                    todosByDate[dateKey]?.append(todo)
                }
            }

            // Sort items within each date
            for (date, items) in todosByDate {
                todosByDate[date] = items.sorted { $0.createdDate > $1.createdDate }
            }

            todosCursor = result.continueCursor
            canLoadMoreTodos = !result.isDone
        } catch {
            print("Failed to load todos: \(error)")
        }
    }

    func refresh() async {
        // Reset pagination state
        sessionsCursor = nil
        todosCursor = nil
        canLoadMoreSessions = true
        canLoadMoreTodos = true
        sessionsByDate = [:]
        todosByDate = [:]

        await loadMoreSessions()
        await loadMoreTodos()
    }
}

#Preview {
    TimelineView()
}
