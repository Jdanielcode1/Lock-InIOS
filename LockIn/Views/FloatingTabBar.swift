//
//  FloatingTabBar.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI

enum Tab: String, CaseIterable {
    case goals = "Goals"
    case timeline = "Timeline"
    case stats = "Stats"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .goals: return "tray.fill"
        case .timeline: return "slider.horizontal.3"
        case .stats: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    var onPlusTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Tab bar container
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(AppTheme.tabBarBackground)
            .clipShape(Capsule())

            Spacer()
                .frame(width: 16)

            // FAB Button
            Button(action: onPlusTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.actionBlue)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.actionBlue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.actionBlue : AppTheme.textSecondary)

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.actionBlue : AppTheme.textSecondary)
            }
            .frame(width: 70, height: 50)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(.timeline)) {
                print("Plus tapped")
            }
        }
    }
}
