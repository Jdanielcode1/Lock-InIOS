//
//  GoalSessionPresenter.swift
//  LockIn
//
//  Created by Claude on 30/12/25.
//

import SwiftUI

class GoalSessionPresenter: ObservableObject {
    @Published var isPresented = false
    @Published var goalId: String?
    @Published var goalTodoId: String?
    @Published var availableTodos: [GoalTodo] = []

    func presentSession(goalId: String, goalTodoId: String? = nil, availableTodos: [GoalTodo] = []) {
        self.goalId = goalId
        self.goalTodoId = goalTodoId
        self.availableTodos = availableTodos
        self.isPresented = true
    }

    func dismiss() {
        isPresented = false
        goalId = nil
        goalTodoId = nil
        availableTodos = []
    }
}
