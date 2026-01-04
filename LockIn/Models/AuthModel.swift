//
//  AuthModel.swift
//  LockIn
//
//  Firebase Authentication model for managing user auth state
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

    init() {
        // Subscribe to Convex auth state
        convexClient.authState.replaceError(with: .unauthenticated)
            .receive(on: DispatchQueue.main)
            .assign(to: &$authState)

        // Try to restore session from Firebase
        // Convex handles token lifecycle automatically via AuthProvider.loginFromCache()
        Task {
            await loginFromCacheWithRetry()
        }
    }

    /// Attempts to login from cache (restore existing Firebase session)
    private func loginFromCacheWithRetry() async {
        do {
            try await convexClient.loginFromCache()
        } catch {
            print("Login from cache failed: \(error.localizedDescription)")
            // No cached session - user needs to sign in
        }
    }

    // MARK: - Sign In Methods

    /// Sign in with Apple
    func signInWithApple() {
        errorMessage = nil
        Task {
            do {
                let result = try await firebaseAuthProvider.signInWithApple()
                // Convex client will be updated automatically via authState subscription
                try await updateConvexAuth(with: result)
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
                try await updateConvexAuth(with: result)
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
                try await updateConvexAuth(with: result)
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
    private func updateConvexAuth(with result: FirebaseAuthResult) async throws {
        // The convexClient will automatically pick up the auth state change
        // We just need to trigger a cache login to sync the token
        try await convexClient.loginFromCache()
    }

    /// Sign out of Firebase and Convex
    func logout() {
        Task {
            do {
                await convexClient.logout()
                print("Logged out successfully")
            } catch {
                print("Logout error: \(error.localizedDescription)")
            }
        }
    }

    /// Force refresh the session by getting a new token
    func refreshSession() {
        isRefreshing = true
        Task {
            do {
                try await convexClient.loginFromCache()
                isRefreshing = false
            } catch {
                print("Session refresh failed: \(error)")
                isRefreshing = false
            }
        }
    }

    /// Refresh session when app comes back from background
    func refreshSessionIfNeeded() {
        if case .authenticated(_) = authState {
            print("App became active - refreshing auth session")
            Task {
                do {
                    try await convexClient.loginFromCache()
                    print("Auth session refreshed successfully")
                } catch {
                    print("Auth refresh failed: \(error.localizedDescription)")
                }
            }
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
