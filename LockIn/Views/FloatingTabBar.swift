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

enum Tab: String {
    case home = "Home"
    case timeline = "Timeline"
    case record = "Record"
    case stats = "Stats"
    case me = "Me"
}
