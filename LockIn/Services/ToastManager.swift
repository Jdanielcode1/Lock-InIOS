//
//  ToastManager.swift
//  LockIn
//
//  Created by Claude on 01/07/26.
//

import SwiftUI

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
        let undoAction: (() -> Void)?
        let duration: TimeInterval

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
            undoAction: undoAction,
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

    /// User tapped undo - cancel hard delete and restore item
    func undo() {
        // Cancel the pending hard delete
        pendingHardDeleteTask?.cancel()
        pendingHardDeleteTask = nil

        // Execute the undo action
        currentToast?.undoAction?()

        // Haptic feedback for undo
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Dismiss the toast
        dismiss()
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
