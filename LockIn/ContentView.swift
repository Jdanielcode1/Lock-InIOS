//
//  ContentView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Tab = .home
    @State private var showingLockIn = false

    @StateObject private var todoViewModel = TodoViewModel()
    @StateObject private var goalsViewModel = GoalsViewModel()
    @StateObject private var tabBarVisibility = TabBarVisibility()

    // Recording session injected from RootView
    @EnvironmentObject private var recordingSession: RecordingSessionManager

    var body: some View {
        TabView(selection: $selectedTab) {
            GoalsListView()
                .environmentObject(tabBarVisibility)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            TimelineView()
                .environmentObject(tabBarVisibility)
                .tabItem {
                    Label("Timeline", systemImage: "clock.fill")
                }
                .tag(Tab.timeline)

            // Center record button placeholder
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                }
                .tag(Tab.record)

            StatsView()
                .environmentObject(tabBarVisibility)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(Tab.stats)

            SettingsView()
                .tabItem {
                    Label("Me", systemImage: "person.fill")
                }
                .tag(Tab.me)
        }
        .tint(.accentColor)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .record {
                selectedTab = oldValue
                showingLockIn = true
            }
        }
        .sheet(isPresented: $showingLockIn) {
            LockInStartView(
                goalsViewModel: goalsViewModel,
                todoViewModel: todoViewModel
            )
            .environmentObject(recordingSession)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingSessionManager.shared)
}
