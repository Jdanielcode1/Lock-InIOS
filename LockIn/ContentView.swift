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
    @State private var showingActionSheet = false

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
        .confirmationDialog("Start Session", isPresented: $showingActionSheet) {
            Button("Create New Goal") {
                showingCreateGoal = true
            }

            Button("Quick Timelapse") {
                // Could open a quick timelapse without goal
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingCreateGoal) {
            CreateGoalView()
        }
    }
}

#Preview {
    ContentView()
}
