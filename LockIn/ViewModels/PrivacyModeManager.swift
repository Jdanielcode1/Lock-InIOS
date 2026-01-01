//
//  PrivacyModeManager.swift
//  LockIn
//
//  Created by Claude on 01/01/26.
//

import SwiftUI
import UIKit

// MARK: - Privacy Level

enum PrivacyLevel: String, CaseIterable, Identifiable {
    case off = "Off"
    case stealth = "Stealth"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .off: return "eye"
        case .stealth: return "eye.slash"
        }
    }

    var description: String {
        switch self {
        case .off: return "All controls visible"
        case .stealth: return "Minimal stopwatch display"
        }
    }
}

// MARK: - Indicator Corner

enum IndicatorCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Privacy Mode Manager

@MainActor
class PrivacyModeManager: ObservableObject {
    @Published var privacyLevel: PrivacyLevel = .off {
        didSet {
            // Auto-activate/deactivate when level changes (for mid-recording changes)
            if privacyLevel == .stealth && !isActive {
                activate()
            } else if privacyLevel == .off && isActive {
                deactivate()
            }
        }
    }
    @Published var isActive: Bool = false
    @Published var showingModeSelector: Bool = false
    @Published var indicatorCorner: IndicatorCorner = .topRight

    private var hapticTimer: Timer?
    private let hapticInterval: TimeInterval = 45.0
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .soft)

    // Computed properties for easy state checking
    var isStealth: Bool { privacyLevel == .stealth && isActive }
    var shouldHideControls: Bool { isStealth }

    init() {
        hapticGenerator.prepare()
    }

    // MARK: - Activation

    func activate() {
        guard privacyLevel != .off else { return }
        isActive = true
        startHapticFeedback()

        // Confirmation haptic
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
    }

    func deactivate() {
        isActive = false
        stopHapticFeedback()

        // Confirmation haptic
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.warning)
    }

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    // MARK: - Auto-activation (when recording starts)

    func onRecordingStarted() {
        if privacyLevel != .off {
            activate()
        }
    }

    func onRecordingStopped() {
        deactivate()
    }

    // MARK: - Haptic Feedback

    private func startHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerSubtleHaptic()
            }
        }
    }

    private func stopHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    private func triggerSubtleHaptic() {
        // Check if haptic feedback is enabled in app settings
        let isHapticEnabled = UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true
        guard isHapticEnabled else { return }

        hapticGenerator.impactOccurred(intensity: 0.4)
    }

    deinit {
        hapticTimer?.invalidate()
    }
}
