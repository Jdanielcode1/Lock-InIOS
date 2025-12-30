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
    @StateObject private var tabBarVisibility = TabBarVisibility()

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
                    SettingsView(selectedTab: $selectedTab)
                }
            }
            .environmentObject(tabBarVisibility)

            // Floating tab bar
            if tabBarVisibility.isVisible {
                FloatingTabBar(selectedTab: $selectedTab) {
                    showingActionSheet = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tabBarVisibility.isVisible)
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
