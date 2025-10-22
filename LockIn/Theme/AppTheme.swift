//
//  AppTheme.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors

    // Primary purple shades
    static let primaryPurple = Color(red: 0.5, green: 0.2, blue: 0.8) // Vibrant purple
    static let lightPurple = Color(red: 0.7, green: 0.5, blue: 0.9)   // Light purple
    static let darkPurple = Color(red: 0.3, green: 0.1, blue: 0.5)    // Dark purple

    // Playful yellow shades
    static let primaryYellow = Color(red: 1.0, green: 0.85, blue: 0.0) // Bright yellow
    static let lightYellow = Color(red: 1.0, green: 0.95, blue: 0.7)   // Soft yellow
    static let darkYellow = Color(red: 0.9, green: 0.7, blue: 0.0)     // Golden yellow

    // Energetic red shades
    static let primaryRed = Color(red: 1.0, green: 0.3, blue: 0.4)    // Playful red
    static let lightRed = Color(red: 1.0, green: 0.6, blue: 0.6)      // Soft red
    static let darkRed = Color(red: 0.8, green: 0.1, blue: 0.2)       // Deep red

    // Neutral colors
    static let background = Color(red: 0.98, green: 0.98, blue: 1.0)  // Slightly purple-tinted white
    static let cardBackground = Color.white
    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.3)   // Dark purple-gray
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.6) // Medium gray

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primaryPurple, primaryRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [primaryYellow, lightYellow],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let energyGradient = LinearGradient(
        colors: [primaryRed, primaryYellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let calmGradient = LinearGradient(
        colors: [lightPurple, primaryPurple],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Typography

    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 14, weight: .medium, design: .rounded)

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8

    // MARK: - Shadows

    static let cardShadow = Color.black.opacity(0.08)

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
            .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
    }

    func primaryButton() -> some View {
        self
            .padding()
            .background(AppTheme.primaryGradient)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    func secondaryButton() -> some View {
        self
            .padding()
            .background(AppTheme.lightPurple.opacity(0.2))
            .foregroundColor(AppTheme.primaryPurple)
            .cornerRadius(AppTheme.smallCornerRadius)
    }
}

// MARK: - Progress Ring Colors

extension AppTheme {
    static func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<25:
            return primaryRed
        case 25..<50:
            return Color(red: 1.0, green: 0.6, blue: 0.2) // Orange
        case 50..<75:
            return primaryYellow
        case 75..<100:
            return lightPurple
        default:
            return primaryPurple // Completed
        }
    }

    static func progressGradient(for percentage: Double) -> LinearGradient {
        let startColor = progressColor(for: percentage)
        let endColor = percentage >= 100 ? primaryPurple : startColor.opacity(0.7)

        return LinearGradient(
            colors: [startColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
