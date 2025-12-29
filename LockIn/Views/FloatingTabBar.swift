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
    @Environment(\.horizontalSizeClass) var sizeClass

    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            // Tab bar container
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab, buttonWidth: sizing.tabButtonWidth) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())

            Spacer()
                .frame(width: 16)

            // FAB Button
            Button(action: onPlusTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }

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
