//
//  TimelineView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI
import Combine

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.actionBlue)
                } else if viewModel.sessionsByDate.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                            ForEach(viewModel.sortedDates, id: \.self) { date in
                                Section {
                                    ForEach(viewModel.sessionsByDate[date] ?? []) { item in
                                        NavigationLink(destination: VideoPlayerView(session: item.session)) {
                                            TimelineCard(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                } header: {
                                    DateHeader(date: date)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
    @Published var isLoading = true

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    var sortedDates: [Date] {
        sessionsByDate.keys.sorted(by: >)
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
