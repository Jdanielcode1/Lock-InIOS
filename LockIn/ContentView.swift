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
    @State private var showingFABMenu = false
    @StateObject private var todoViewModel = TodoViewModel()
    @StateObject private var tabBarVisibility = TabBarVisibility()

    // Recording session injected from RootView
    @EnvironmentObject private var recordingSession: RecordingSessionManager

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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingFABMenu = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // FAB Popup Menu
            FABPopupMenu(isPresented: $showingFABMenu) {
                showingCreateGoal = true
            } onNewTodo: {
                showingCreateTodo = true
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tabBarVisibility.isVisible)
        .sheet(isPresented: $showingCreateGoal) {
            CreateGoalView()
        }
        .sheet(isPresented: $showingCreateTodo) {
            AddTodoSheet(viewModel: todoViewModel)
        }
        // Recording sessions are now presented at RootView level to survive auth state changes
    }
}

#Preview {
    ContentView()
}
