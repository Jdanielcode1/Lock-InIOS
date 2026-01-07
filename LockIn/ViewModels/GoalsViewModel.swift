//
//  GoalsViewModel.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import Combine
import ConvexMobile

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var dataSubscription: AnyCancellable?  // Separate subscription for data (can be cancelled on auth loss)
    private var isSubscribed = false  // Track subscription state to avoid duplicates
    private let convexService = ConvexService.shared

    init() {
        // Load cached data immediately for instant UI
        loadCachedGoals()
        monitorAuthAndSubscribe()
    }

    /// Load cached goals for instant app launch
    private func loadCachedGoals() {
        Task {
            if let cached: [Goal] = await DataCacheService.shared.load(.goals) {
                // Only set if we don't have data yet (avoid flicker)
                if self.goals.isEmpty {
                    self.goals = cached
                }
            }
        }
    }

    /// Continuously monitor auth state and subscribe/unsubscribe accordingly
    /// This ensures we recover from auth token expiration
    private func monitorAuthAndSubscribe() {
        isLoading = true

        convexClient.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }

                switch state {
                case .authenticated:
                    // Only subscribe if not already subscribed (avoid duplicates)
                    if !self.isSubscribed {
                        print("🔄 GoalsViewModel: Auth recovered, re-subscribing...")
                        self.subscribeToGoals()
                    }
                case .unauthenticated:
                    // Cancel data subscription on auth loss (will re-subscribe on recovery)
                    self.cancelDataSubscription()
                case .loading:
                    // Keep current state while loading
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToGoals() {
        isSubscribed = true

        dataSubscription = convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.goals = goals
                self?.isLoading = false

                // Update cache in background
                Task {
                    await DataCacheService.shared.save(goals, for: .goals)
                }
            }
    }

    private func cancelDataSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil
        isSubscribed = false
        // Don't clear goals - keep showing cached data
        print("⚠️ GoalsViewModel: Auth lost, subscription cancelled (keeping cached data)")
    }

    func createGoal(title: String, description: String, targetHours: Double) async {
        do {
            _ = try await convexService.createGoal(
                title: title,
                description: description,
                targetHours: targetHours
            )
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't create goal. Please try again."))
        }
    }

    /// Creates a goal and returns the goal ID for adding tasks
    func createGoalReturningId(title: String, description: String, targetHours: Double) async -> String? {
        do {
            return try await convexService.createGoal(
                title: title,
                description: description,
                targetHours: targetHours
            )
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't create goal. Please try again."))
            return nil
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await convexService.deleteGoal(id: goal.id)
        } catch {
            errorMessage = "Failed to delete goal: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't delete goal. Please try again."))
        }
    }

    func updateGoalStatus(_ goal: Goal, status: GoalStatus) async {
        do {
            try await convexService.updateGoalStatus(id: goal.id, status: status)
        } catch {
            errorMessage = "Failed to update goal: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't update goal status. Please try again."))
        }
    }

    func moveGoal(from source: IndexSet, to destination: Int) {
        goals.move(fromOffsets: source, toOffset: destination)
    }

    func archiveGoal(_ goal: Goal) async {
        do {
            try await convexService.archiveGoal(id: goal.id)
        } catch {
            errorMessage = "Failed to archive goal: \(error.localizedDescription)"
            ErrorAlertManager.shared.show(.saveFailed("Couldn't archive goal. Please try again."))
        }
    }
}
