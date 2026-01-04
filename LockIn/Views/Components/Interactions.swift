//
//  Interactions.swift
//  LockIn
//
//  Reusable button styles, animations, and haptic feedback patterns
//

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {
    // Animation
    static let springResponse: CGFloat = 0.3
    static let springDamping: CGFloat = 0.7
    static let pressScale: CGFloat = 0.96

    // Sizing
    static let avatarSmall: CGFloat = 44
    static let avatarMedium: CGFloat = 52
    static let avatarLarge: CGFloat = 60
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
}

// MARK: - Press Button Style

/// Button style with scale animation and light haptic feedback on press
struct PressButtonStyle: ButtonStyle {
    var scale: CGFloat = DesignTokens.pressScale
    var enableHaptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && enableHaptic {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Bounce Button Style

/// Button style with subtle bounce animation
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Soft Button Style

/// Gentle button style for secondary actions
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply press animation to any view
    func pressAnimation(scale: CGFloat = DesignTokens.pressScale) -> some View {
        self.buttonStyle(PressButtonStyle(scale: scale))
    }

    /// Apply bounce animation to any view
    func bounceAnimation() -> some View {
        self.buttonStyle(BounceButtonStyle())
    }

    /// Apply soft press animation to any view
    func softPressAnimation() -> some View {
        self.buttonStyle(SoftButtonStyle())
    }
}

// MARK: - Haptic Feedback Utilities

enum HapticFeedback {
    /// Light impact feedback
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium impact feedback
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy impact feedback
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Success notification feedback
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning notification feedback
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error notification feedback
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Selection changed feedback
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Celebration haptic pattern - triple tap for achievements
    static func celebration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Soft double tap for subtle confirmations
    static func softConfirm() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

// MARK: - Animation Helpers

extension Animation {
    /// Standard spring animation for UI interactions
    static var smooth: Animation {
        .spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)
    }

    /// Bouncy spring animation for celebratory moments
    static var bouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }

    /// Quick spring animation for micro-interactions
    static var quick: Animation {
        .spring(response: 0.2, dampingFraction: 0.8)
    }
}

// MARK: - Entrance Animations

struct SlideUpModifier: ViewModifier {
    let isPresented: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: isPresented ? 0 : 20)
            .opacity(isPresented ? 1 : 0)
            .animation(.smooth.delay(delay), value: isPresented)
    }
}

struct ScaleUpModifier: ViewModifier {
    let isPresented: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
            .animation(.bouncy.delay(delay), value: isPresented)
    }
}

extension View {
    /// Slide up entrance animation
    func slideUp(isPresented: Bool, delay: Double = 0) -> some View {
        modifier(SlideUpModifier(isPresented: isPresented, delay: delay))
    }

    /// Scale up entrance animation
    func scaleUp(isPresented: Bool, delay: Double = 0) -> some View {
        modifier(ScaleUpModifier(isPresented: isPresented, delay: delay))
    }
}

// MARK: - Pulsing Animation

struct InteractionPulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    /// Apply pulsing animation
    func pulsingEffect() -> some View {
        modifier(InteractionPulsingModifier())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        Button("Press Me") {
            HapticFeedback.success()
        }
        .padding()
        .background(Color.accentColor)
        .foregroundStyle(.white)
        .cornerRadius(12)
        .buttonStyle(PressButtonStyle())

        Button("Bounce Me") {
            HapticFeedback.celebration()
        }
        .padding()
        .background(Color.green)
        .foregroundStyle(.white)
        .cornerRadius(12)
        .buttonStyle(BounceButtonStyle())

        Circle()
            .fill(Color.orange)
            .frame(width: 60, height: 60)
            .pulsingEffect()
    }
    .padding()
}
