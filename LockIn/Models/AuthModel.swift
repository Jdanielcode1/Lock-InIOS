//
//  AuthModel.swift
//  LockIn
//
//  Firebase Authentication model for managing user auth state
//
//  Convex Philosophy: Keep It Simple
//  - Queries return empty when unauthenticated (handled by backend)
//  - Subscriptions auto-update when auth becomes valid
//  - No complex client-side token refresh timers needed
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

        // Try to restore session from Firebase on init
        Task {
            _ = await convexClient.loginFromCache()
        }
    }

    /// Call when app comes to foreground - refresh auth session
    func appDidBecomeActive() {
        Task {
            _ = await convexClient.loginFromCache()
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
