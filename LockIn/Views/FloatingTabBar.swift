//
//  FloatingTabBar.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI

// Observable class to control tab bar visibility
class TabBarVisibility: ObservableObject {
    @Published private(set) var isVisible: Bool = true
    private var hideCount: Int = 0

    func hide() {
        hideCount += 1
        updateVisibility()
    }

    func show() {
        hideCount = max(0, hideCount - 1)
        updateVisibility()
    }

    private func updateVisibility() {
        isVisible = hideCount == 0
    }
}

enum Tab: String, CaseIterable {
    case home = "Home"
    case timeline = "Timeline"
    case stats = "Stats"
    case me = "Me"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .timeline: return "list.bullet.rectangle"
        case .stats: return "chart.bar.fill"
        case .me: return "person.fill"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    var onPlusTapped: () -> Void
    @Environment(\.horizontalSizeClass) var sizeClass

    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    // Tabs on the left side of FAB
    private var leftTabs: [Tab] { [.home, .timeline] }
    // Tabs on the right side of FAB
    private var rightTabs: [Tab] { [.stats, .me] }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            // Tab bar container with centered FAB
            HStack(spacing: 0) {
                // Left tabs
                ForEach(leftTabs, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab, buttonWidth: sizing.tabButtonWidth) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }

                // Center FAB
                Button(action: onPlusTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 8)

                // Right tabs
                ForEach(rightTabs, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab, buttonWidth: sizing.tabButtonWidth) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .frame(maxWidth: sizing.tabBarMaxWidth)
        .frame(maxWidth: .infinity) // Center within parent
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    var buttonWidth: CGFloat = 70
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(width: buttonWidth, height: 50)
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
