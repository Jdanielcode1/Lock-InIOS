//
//  ContentView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .goals
    @State private var showingCreateGoal = false
    @State private var showingCreateTodo = false
    @State private var showingActionSheet = false
    @StateObject private var todoViewModel = TodoViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .goals:
                    GoalsListView()
                case .timeline:
                    TimelineView()
                case .stats:
                    StatsView()
                case .settings:
                    SettingsView()
                }
            }

            // Floating tab bar
            FloatingTabBar(selectedTab: $selectedTab) {
                showingActionSheet = true
            }
        }
        .confirmationDialog("Create New", isPresented: $showingActionSheet) {
            Button("New Goal") {
                showingCreateGoal = true
            }

            Button("New To-Do") {
                showingCreateTodo = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingCreateGoal) {
            CreateGoalView()
        }
        .sheet(isPresented: $showingCreateTodo) {
            AddTodoSheet(viewModel: todoViewModel)
        }
    }
}

#Preview {
    ContentView()
}
