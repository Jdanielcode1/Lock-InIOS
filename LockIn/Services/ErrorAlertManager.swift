//
//  ErrorAlertManager.swift
//  LockIn
//
//  Created by Claude on 01/02/26.
//

import SwiftUI

/// Manages user-facing error alerts throughout the app
@MainActor
class ErrorAlertManager: ObservableObject {
    static let shared = ErrorAlertManager()

    @Published var currentError: AppError?
    @Published var showingAlert: Bool = false

    private init() {}

    /// Show an error alert to the user
    func show(_ error: AppError) {
        currentError = error
        showingAlert = true

        // Haptic feedback for errors
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Show an error from a thrown Error
    func show(_ error: Error, context: String? = nil) {
        let appError = AppError.from(error, context: context)
        show(appError)
    }

    /// Dismiss the current error
    func dismiss() {
        showingAlert = false
        currentError = nil
    }
}

/// App-specific error types with user-friendly messages
enum AppError: LocalizedError, Identifiable {
    case networkError(String?)
    case saveFailed(String?)
    case loadFailed(String?)
    case videoError(String?)
    case authError(String?)
    case unknown(String?)

    var id: String {
        switch self {
        case .networkError: return "network"
        case .saveFailed: return "save"
        case .loadFailed: return "load"
        case .videoError: return "video"
        case .authError: return "auth"
        case .unknown: return "unknown"
        }
    }

    var title: String {
        switch self {
        case .networkError: return "Connection Error"
        case .saveFailed: return "Save Failed"
        case .loadFailed: return "Load Failed"
        case .videoError: return "Video Error"
        case .authError: return "Authentication Error"
        case .unknown: return "Something Went Wrong"
        }
    }

    var errorDescription: String? {
        switch self {
        case .networkError(let detail):
            return detail ?? "Please check your internet connection and try again."
        case .saveFailed(let detail):
            return detail ?? "Your changes couldn't be saved. Please try again."
        case .loadFailed(let detail):
            return detail ?? "Couldn't load the data. Pull to refresh or try again later."
        case .videoError(let detail):
            return detail ?? "There was a problem with the video. Please try recording again."
        case .authError(let detail):
            return detail ?? "Please sign in again to continue."
        case .unknown(let detail):
            return detail ?? "An unexpected error occurred. Please try again."
        }
    }

    var systemImage: String {
        switch self {
        case .networkError: return "wifi.slash"
        case .saveFailed: return "xmark.icloud"
        case .loadFailed: return "arrow.clockwise"
        case .videoError: return "video.slash"
        case .authError: return "person.crop.circle.badge.exclamationmark"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    /// Create an AppError from a thrown Error
    static func from(_ error: Error, context: String? = nil) -> AppError {
        let errorMessage = error.localizedDescription

        // Check for common error patterns
        if errorMessage.lowercased().contains("network") ||
           errorMessage.lowercased().contains("internet") ||
           errorMessage.lowercased().contains("connection") ||
           errorMessage.lowercased().contains("offline") {
            return .networkError(context)
        }

        if errorMessage.lowercased().contains("auth") ||
           errorMessage.lowercased().contains("sign in") ||
           errorMessage.lowercased().contains("login") ||
           errorMessage.lowercased().contains("unauthorized") {
            return .authError(context)
        }

        if errorMessage.lowercased().contains("video") ||
           errorMessage.lowercased().contains("recording") ||
           errorMessage.lowercased().contains("encode") {
            return .videoError(context)
        }

        return .unknown(context ?? errorMessage)
    }
}

// MARK: - View Modifier for Error Alerts

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorAlertManager.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: $errorManager.showingAlert,
                presenting: errorManager.currentError
            ) { _ in
                Button("OK") {
                    errorManager.dismiss()
                }
            } message: { error in
                Text(error.errorDescription ?? "An error occurred")
            }
    }
}

extension View {
    /// Adds app-wide error alert handling to this view
    func withErrorAlerts() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Convenience for async operations with error handling

extension View {
    /// Perform an async operation and show error alert on failure
    func performWithErrorAlert(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch {
                await MainActor.run {
                    ErrorAlertManager.shared.show(error)
                }
            }
        }
    }
}
