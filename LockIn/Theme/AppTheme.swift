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

    // MARK: - Neutral Colors

    // Backgrounds
    static let background = Color(red: 0.98, green: 0.98, blue: 0.98)      // #FAFAFA - clean white
    static let cardBackground = Color.white

    // Text
    static let textPrimary = Color(red: 0.13, green: 0.13, blue: 0.14)     // #212123 - near black
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.58)   // #8C8C94 - medium gray

    // Borders & Dividers
    static let borderLight = Color(red: 0.91, green: 0.91, blue: 0.92)     // #E8E8EB
    static let borderMedium = Color(red: 0.82, green: 0.82, blue: 0.84)    // #D1D1D6

    // Tab Bar
    static let tabBarBackground = Color(red: 0.12, green: 0.12, blue: 0.14) // #1F1F23

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

    // MARK: - Typography

    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 14, weight: .medium, design: .rounded)

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8

    // MARK: - Shadows

    static let cardShadow = Color.black.opacity(0.06)

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
            .padding()
            .background(AppTheme.actionBlue)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: AppTheme.actionBlue.opacity(0.3), radius: 6, x: 0, y: 3)
    }

    func secondaryButton() -> some View {
        self
            .padding()
            .background(AppTheme.actionBlueLight.opacity(0.15))
            .foregroundColor(AppTheme.actionBlue)
            .cornerRadius(AppTheme.smallCornerRadius)
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
