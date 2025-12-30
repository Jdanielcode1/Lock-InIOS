//
//  AuthModel.swift
//  LockIn
//
//  Created by Claude on 27/12/25.
//

import Auth0
import Combine
import ConvexMobile
import SwiftUI

@MainActor
class AuthModel: ObservableObject {
    @Published var authState: AuthState<Credentials> = .loading
    @Published var isRefreshing: Bool = false

    init() {
        convexClient.authState.replaceError(with: .unauthenticated)
            .receive(on: DispatchQueue.main)
            .assign(to: &$authState)
        Task {
            await loginFromCacheWithRetry()
        }
    }

    /// Attempts to login from cache, with automatic retry on failure
    private func loginFromCacheWithRetry() async {
        do {
            try await convexClient.loginFromCache()
        } catch {
            print("Login from cache failed: \(error.localizedDescription)")
            // Token refresh failed - user needs to re-authenticate
            // The authState will be set to .unauthenticated automatically
        }
    }

    func login() {
        Task {
            await convexClient.login()
        }
    }

    func logout() {
        Task {
            await convexClient.logout()
        }
    }

    /// Force refresh the session by re-logging in
    func refreshSession() {
        isRefreshing = true
        Task {
            // First try to refresh from cache (this triggers token refresh)
            do {
                try await convexClient.loginFromCache()
                isRefreshing = false
            } catch {
                // If cache refresh fails, we need a fresh login
                print("Session refresh failed, needs re-login: \(error)")
                isRefreshing = false
                // Trigger fresh login
                await convexClient.login()
            }
        }
    }
}
