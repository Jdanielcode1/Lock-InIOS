//
//  GoalsViewModel.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import Foundation
import Combine

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    init() {
        subscribeToGoals()
    }

    private func subscribeToGoals() {
        isLoading = true

        convexService.listGoals()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goals in
                self?.goals = goals
                self?.isLoading = false
            }
            .store(in: &cancellables)
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
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await convexService.deleteGoal(id: goal.id)
        } catch {
            errorMessage = "Failed to delete goal: \(error.localizedDescription)"
        }
    }

    func updateGoalStatus(_ goal: Goal, status: GoalStatus) async {
        do {
            try await convexService.updateGoalStatus(id: goal.id, status: status)
        } catch {
            errorMessage = "Failed to update goal: \(error.localizedDescription)"
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
        }
    }
}
