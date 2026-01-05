//
//  AuthModel.swift
//  LockIn
//
//  Firebase Authentication model for managing user auth state
//
//  Standard Convex Auth Pattern:
//  - Backend throws on unauthenticated (security + clear errors)
//  - iOS proactively refreshes token before expiration
//  - Timer runs every 45 mins to keep token fresh
//

import FirebaseAuth
import Combine
import ConvexMobile
import SwiftUI
import AuthenticationServices

/// Sign-in method options
enum SignInMethod {
    case apple
    case google
    case anonymous
}

@MainActor
class AuthModel: ObservableObject {
    @Published var authState: AuthState<FirebaseAuthResult> = .loading
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    // Token refresh timer (Firebase tokens expire after 1 hour)
    private var tokenRefreshTimer: Timer?
    private let tokenRefreshInterval: TimeInterval = 45 * 60 // 45 minutes

    init() {
        // Subscribe to Convex auth state
        convexClient.authState.replaceError(with: .unauthenticated)
            .receive(on: DispatchQueue.main)
            .assign(to: &$authState)

        // Try to restore session from Firebase on init
        Task {
            _ = await convexClient.loginFromCache()
        }

        // Start token refresh timer
        startTokenRefreshTimer()
    }

    deinit {
        tokenRefreshTimer?.invalidate()
    }

    // MARK: - Token Refresh Timer

    private func startTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: tokenRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTokenIfNeeded()
            }
        }
    }

    private func stopTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }

    private func refreshTokenIfNeeded() async {
        guard case .authenticated = authState else { return }
        isRefreshing = true
        _ = await convexClient.loginFromCache()
        isRefreshing = false
    }

    /// Call when app comes to foreground - refresh auth session and restart timer
    func appDidBecomeActive() {
        Task {
            _ = await convexClient.loginFromCache()
        }
        startTokenRefreshTimer()
    }

    /// Call when app goes to background - stop timer to save resources
    func appDidEnterBackground() {
        stopTokenRefreshTimer()
    }

    // MARK: - Sign In Methods

    /// Sign in with Apple
    func signInWithApple() {
        errorMessage = nil
        Task {
            do {
                let result = try await firebaseAuthProvider.signInWithApple()
                // Convex client will be updated automatically via authState subscription
                await updateConvexAuth(with: result)
            } catch {
                handleAuthError(error)
            }
        }
    }

    /// Sign in with Google
    func signInWithGoogle() {
        errorMessage = nil
        Task {
            do {
                let result = try await firebaseAuthProvider.signInWithGoogle()
                await updateConvexAuth(with: result)
            } catch {
                handleAuthError(error)
            }
        }
    }

    /// Sign in anonymously (guest mode)
    func signInAnonymously() {
        errorMessage = nil
        Task {
            do {
                let result = try await firebaseAuthProvider.signInAnonymously()
                await updateConvexAuth(with: result)
            } catch {
                handleAuthError(error)
            }
        }
    }

    /// Generic login - defaults to showing options (handled by LoginView)
    func login() {
        // This is called by convexClient.login() - we use specific methods instead
        // For backwards compatibility, default to anonymous
        signInAnonymously()
    }

    // MARK: - Session Management

    /// Update Convex with the Firebase auth result
    private func updateConvexAuth(with result: FirebaseAuthResult) async {
        // The convexClient will automatically pick up the auth state change
        // We just need to trigger a cache login to sync the token
        _ = await convexClient.loginFromCache()
    }

    /// Sign out of Firebase and Convex
    func logout() {
        Task {
            await convexClient.logout()
            print("Logged out successfully")
        }
    }

    // MARK: - Error Handling

    private func handleAuthError(_ error: Error) {
        if let authError = error as? FirebaseAuthError {
            errorMessage = authError.errorDescription
        } else if (error as NSError).domain == ASAuthorizationError.errorDomain {
            let authError = error as NSError
            if authError.code == ASAuthorizationError.canceled.rawValue {
                // User cancelled - not an error
                errorMessage = nil
                return
            }
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        } else {
            errorMessage = error.localizedDescription
        }
        print("Auth error: \(error)")
    }

    /// Check if current user is anonymous (guest)
    var isAnonymousUser: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }

    /// Get current user's display name
    var displayName: String? {
        return Auth.auth().currentUser?.displayName
    }

    /// Get current user's email
    var email: String? {
        return Auth.auth().currentUser?.email
    }
}
