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

    init() {
        convexClient.authState.replaceError(with: .unauthenticated)
            .receive(on: DispatchQueue.main)
            .assign(to: &$authState)
        Task {
            await convexClient.loginFromCache()
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
}
