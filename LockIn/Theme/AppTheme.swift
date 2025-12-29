//
//  AppTheme.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct AppTheme {
    // MARK: - Primary Action Colors

    // Action Blue - primary actions, buttons, links
    static let actionBlue = Color(red: 0.25, green: 0.52, blue: 0.96)       // #4085F5
    static let actionBlueLight = Color(red: 0.35, green: 0.62, blue: 0.98) // Lighter variant
    static let actionBlueDark = Color(red: 0.18, green: 0.42, blue: 0.82)  // Darker variant

    // MARK: - Semantic Colors

    // Success Green - completed, achieved
    static let successGreen = Color(red: 0.26, green: 0.70, blue: 0.46)    // #43B376

    // Warning Amber - due soon, medium priority
    static let warningAmber = Color(red: 0.95, green: 0.68, blue: 0.25)    // #F2AD40

    // Urgent Red - overdue, high priority (use sparingly)
    static let urgentRed = Color(red: 0.90, green: 0.35, blue: 0.35)       // #E65959

    // MARK: - Adaptive Colors (Light/Dark Mode)

    // Backgrounds - use system colors for automatic light/dark adaptation
    static let background = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // Text - use system label colors for automatic adaptation
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)

    // Borders & Dividers - use system separators
    static let borderLight = Color(UIColor.separator)
    static let borderMedium = Color(UIColor.opaqueSeparator)

    // Tab Bar - adaptive dark surface
    static let tabBarBackground = Color(UIColor.secondarySystemBackground)

    // MARK: - Legacy Aliases (for compatibility)

    static let primaryPurple = actionBlue
    static let lightPurple = actionBlueLight
    static let darkPurple = actionBlueDark
    static let primaryYellow = warningAmber
    static let primaryRed = urgentRed
    static let lightRed = urgentRed.opacity(0.7)
    static let darkRed = Color(red: 0.70, green: 0.25, blue: 0.25)

    // MARK: - Gradients

    // Primary gradient - subtle blue gradient
    static let primaryGradient = LinearGradient(
        colors: [actionBlue, actionBlueDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Success gradient - for completed states
    static let successGradient = LinearGradient(
        colors: [successGreen, successGreen.opacity(0.85)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Energy gradient - for duration/time indicators
    static let energyGradient = LinearGradient(
        colors: [actionBlue, actionBlueLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Calm gradient - subtle background accent
    static let calmGradient = LinearGradient(
        colors: [actionBlueLight.opacity(0.3), actionBlue.opacity(0.1)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Typography (Apple SF Pro - system default)

    static let titleFont = Font.largeTitle.bold()
    static let headlineFont = Font.headline
    static let subheadlineFont = Font.subheadline
    static let bodyFont = Font.body
    static let captionFont = Font.caption

    // MARK: - Apple System Semantic Colors

    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let labelColor = Color(UIColor.label)
    static let secondaryLabelColor = Color(UIColor.secondaryLabel)
    static let tertiaryLabelColor = Color(UIColor.tertiaryLabel)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8

    // MARK: - Shadows

    static let cardShadow = Color(UIColor.label).opacity(0.06)

    // MARK: - Animations

    static let bounceAnimation = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    static let smoothAnimation = Animation.easeInOut(duration: 0.3)
}

// MARK: - View Extensions

extension View {
    func playfulCard() -> some View {
        self
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 2)
    }

    func primaryButton() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
    }

    func secondaryButton() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.12))
            .foregroundColor(.accentColor)
            .cornerRadius(10)
    }

    // Apple-native filled button style
    func appleFilledButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

// MARK: - Progress Ring Colors

extension AppTheme {
    static func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return warningAmber      // In progress - amber
        case 50..<100:
            return actionBlue        // Good progress - blue
        default:
            return successGreen      // Completed - green
        }
    }

    static func progressGradient(for percentage: Double) -> LinearGradient {
        let color = progressColor(for: percentage)

        return LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Adaptive Sizing for iPad

struct AdaptiveSizing {
    let horizontalSizeClass: UserInterfaceSizeClass?

    var isIPad: Bool { horizontalSizeClass == .regular }

    // Grid columns
    var gridColumns: Int { isIPad ? 2 : 1 }
    var wideGridColumns: Int { isIPad ? 3 : 1 }
    var statsGridColumns: Int { isIPad ? 4 : 2 }

    // Spacing
    var cardSpacing: CGFloat { isIPad ? 24 : 16 }
    var horizontalPadding: CGFloat { isIPad ? 32 : 16 }
    var sectionSpacing: CGFloat { isIPad ? 32 : 20 }

    // Card sizes
    var thumbnailSize: CGSize { isIPad ? CGSize(width: 120, height: 90) : CGSize(width: 80, height: 60) }
    var progressCircleSize: CGFloat { isIPad ? 80 : 60 }

    // Tab bar
    var tabButtonWidth: CGFloat { isIPad ? 90 : 70 }
    var tabBarMaxWidth: CGFloat { isIPad ? 500 : .infinity }

    // Content constraints
    var maxContentWidth: CGFloat { isIPad ? 800 : .infinity }

    // Helper to create grid columns
    func gridItems(count: Int? = nil, spacing: CGFloat? = nil) -> [GridItem] {
        let columnCount = count ?? gridColumns
        let itemSpacing = spacing ?? cardSpacing
        return Array(repeating: GridItem(.flexible(), spacing: itemSpacing), count: columnCount)
    }
}
