//
//  ToastManager.swift
//  LockIn
//
//  Created by Claude on 01/07/26.
//

import SwiftUI

/// Toast type for different notification styles
enum ToastType: Equatable {
    case deletion
    case uploadStarted
    case uploadComplete
    case uploadFailed

    var icon: String {
        switch self {
        case .deletion: return "trash.fill"
        case .uploadStarted: return "arrow.up.circle.fill"
        case .uploadComplete: return "checkmark.circle.fill"
        case .uploadFailed: return "exclamationmark.circle.fill"
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .deletion: return .darkGray
        case .uploadStarted: return UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        case .uploadComplete: return UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1)
        case .uploadFailed: return UIColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1)
        }
    }
}

/// Manages toast notifications for deletion confirmations with undo support
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: Toast?
    @Published var isVisible: Bool = false

    private var dismissTask: Task<Void, Never>?
    private var pendingHardDeleteTask: Task<Void, Never>?

    private init() {}

    /// Toast data structure
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastType
        let actionLabel: String?
        let action: (() -> Void)?
        let duration: TimeInterval

        // For deletion toasts (backward compatibility)
        var undoAction: (() -> Void)? {
            type == .deletion ? action : nil
        }

        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Show a deletion toast with optional undo action
    /// - Parameters:
    ///   - itemName: Name of the deleted item (e.g., "Goal", "Task", "To-do")
    ///   - undoAction: Optional closure to execute if user taps Undo
    ///   - hardDeleteAction: Optional closure to execute after undo window expires
    func showDeleted(
        _ itemName: String,
        undoAction: (() -> Void)? = nil,
        hardDeleteAction: (() -> Void)? = nil
    ) {
        // Cancel any existing toast
        dismissTask?.cancel()
        pendingHardDeleteTask?.cancel()

        let toast = Toast(
            message: "\(itemName) deleted",
            type: .deletion,
            actionLabel: undoAction != nil ? "Undo" : nil,
            action: undoAction,
            duration: 4.0
        )

        currentToast = toast

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Schedule auto-dismiss
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.dismiss()
            }
        }

        // Schedule hard delete after undo window
        if let hardDelete = hardDeleteAction {
            pendingHardDeleteTask = Task {
                try? await Task.sleep(for: .seconds(toast.duration))
                guard !Task.isCancelled else { return }
                hardDelete()
            }
        }
    }

    // MARK: - Upload Toasts

    /// Show upload started toast
    func showUploadStarted() {
        showToast(
            message: "Uploading video...",
            type: .uploadStarted,
            duration: 2.0
        )
    }

    /// Show upload complete toast
    func showUploadComplete() {
        showToast(
            message: "Video shared successfully",
            type: .uploadComplete,
            duration: 2.5
        )
    }

    /// Show upload failed toast with retry action
    func showUploadFailed(retryAction: @escaping () -> Void) {
        dismissTask?.cancel()

        let toast = Toast(
            message: "Upload failed",
            type: .uploadFailed,
            actionLabel: "Retry",
            action: retryAction,
            duration: 5.0
        )

        currentToast = toast

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.dismiss()
            }
        }
    }

    /// Generic toast display
    private func showToast(message: String, type: ToastType, duration: TimeInterval) {
        dismissTask?.cancel()

        let toast = Toast(
            message: message,
            type: type,
            actionLabel: nil,
            action: nil,
            duration: duration
        )

        currentToast = toast

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.dismiss()
            }
        }
    }

    /// User tapped action button (undo, retry, etc.)
    func performAction() {
        // Cancel the pending hard delete (for deletion toasts)
        pendingHardDeleteTask?.cancel()
        pendingHardDeleteTask = nil

        // Execute the action
        currentToast?.action?()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Dismiss the toast
        dismiss()
    }

    /// Alias for backward compatibility
    func undo() {
        performAction()
    }

    /// Dismiss the toast (no undo)
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isVisible = false
        }

        // Clear toast after animation
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                self.currentToast = nil
            }
        }
    }

    /// Cancel any pending deletion (used when user undoes before toast disappears)
    func cancelPendingDeletion() {
        pendingHardDeleteTask?.cancel()
        pendingHardDeleteTask = nil
    }
}
