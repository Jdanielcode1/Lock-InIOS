//
//  AppTheme.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct AppTheme {
    // MARK: - Primary Accent Colors (Apple Notes Yellow)

    /// Primary accent - Apple Notes Yellow #FFD60A
    static let accentYellow = Color(hex: "FFD60A")
    static let accentYellowLight = Color(hex: "FFE066")
    static let accentYellowDark = Color(hex: "E6C009")

    // MARK: - Secondary Accent (FaceTime Green)

    /// Secondary accent - FaceTime Green #34C759
    static let accentGreen = Color(hex: "34C759")
    static let accentGreenLight = Color(hex: "4CD964")
    static let accentGreenDark = Color(hex: "28A745")

    // MARK: - Logo-Inspired Charcoal Palette

    /// Deep charcoal - matches logo background dark areas
    static let charcoalDeep = Color(hex: "1C1C1E")
    /// Mid charcoal - logo gradient mid-tones
    static let charcoalMid = Color(hex: "2C2C2E")
    /// Light charcoal - elevated surfaces
    static let charcoalLight = Color(hex: "3A3A3C")
    /// Silver metallic - like the logo icon
    static let silverMetallic = Color(hex: "8E8E93")

    // MARK: - Semantic Colors

    /// Success - use green for completed states
    static let successGreen = accentGreen

    /// Warning - use yellow for attention/caution
    static let warningYellow = accentYellow

    /// Urgent/Error - muted red that works with the palette
    static let urgentRed = Color(hex: "FF453A")
    static let urgentRedLight = Color(hex: "FF6961")

    /// Info - subtle blue for informational states
    static let infoBlue = Color(hex: "64D2FF")

    // MARK: - Adaptive Colors (Light/Dark Mode)

    // Backgrounds - use system colors for automatic light/dark adaptation
    static let background = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // Text - use system label colors for automatic adaptation
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // Borders & Dividers - use system separators
    static let borderLight = Color(UIColor.separator)
    static let borderMedium = Color(UIColor.opaqueSeparator)

    // Tab Bar - adaptive dark surface
    static let tabBarBackground = Color(UIColor.secondarySystemBackground)

    // MARK: - Legacy Aliases (for compatibility)

    static let actionBlue = infoBlue
    static let actionBlueLight = Color(hex: "70D7FF")
    static let actionBlueDark = Color(hex: "50C8FF")
    static let primaryPurple = accentYellow  // Legacy: now yellow
    static let lightPurple = accentYellowLight
    static let darkPurple = accentYellowDark
    static let primaryYellow = accentYellow
    static let primaryRed = urgentRed
    static let lightRed = urgentRedLight
    static let darkRed = Color(hex: "D32F2F")

    // MARK: - Gradients

    /// Primary gradient - warm yellow glow
    static let primaryGradient = LinearGradient(
        colors: [accentYellow, accentYellowDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient - for completed states
    static let successGradient = LinearGradient(
        colors: [accentGreen, accentGreenDark],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Energy gradient - yellow to green for progress
    static let energyGradient = LinearGradient(
        colors: [accentYellow, accentGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Charcoal gradient - matches logo background
    static let charcoalGradient = LinearGradient(
        colors: [charcoalMid, charcoalDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Metallic gradient - subtle silver shine like logo icon
    static let metallicGradient = LinearGradient(
        colors: [silverMetallic.opacity(0.8), silverMetallic.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Calm gradient - subtle background accent
    static let calmGradient = LinearGradient(
        colors: [accentYellow.opacity(0.15), accentGreen.opacity(0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Recording State Colors

    /// Recording active - pulsing indicator
    static let recordingRed = Color(hex: "FF3B30")

    /// Recording paused
    static let recordingPaused = accentYellow

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
    static let yellowGlow = accentYellow.opacity(0.3)
    static let greenGlow = accentGreen.opacity(0.3)

    // MARK: - Animations

    static let bounceAnimation = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    static let smoothAnimation = Animation.easeInOut(duration: 0.3)

    // MARK: - Privacy Mode Colors

    static let privacyPurple = Color(hex: "BF5AF2")
    static let privacyPurpleLight = privacyPurple.opacity(0.2)
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
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
            .foregroundColor(.black)
            .cornerRadius(10)
    }

    func secondaryButton() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.15))
            .foregroundColor(.accentColor)
            .cornerRadius(10)
    }

    // Apple-native filled button style - GREEN for primary actions (Start, Create, Submit)
    func appleFilledButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentGreen)
            .foregroundColor(.white)
            .cornerRadius(12)
    }

    // Neutral button style - GRAY for navigation/secondary actions (Continue, Cancel)
    func neutralFilledButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(UIColor.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
    }

    // Yellow accent button - for branded/recording elements
    func yellowFilledButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentYellow)
            .foregroundColor(.black)
            .cornerRadius(12)
    }
}

// MARK: - Progress Ring Colors

extension AppTheme {
    static func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return accentYellow       // In progress - yellow
        case 50..<100:
            return accentGreen        // Good progress - green
        default:
            return accentGreen        // Completed - green
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
