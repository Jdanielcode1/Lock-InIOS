//
//  LockInApp.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import ConvexMobile

@main
struct LockInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authModel = AuthModel()

    var body: some Scene {
        WindowGroup {
            RootView(authModel: authModel)
        }
    }
}

// MARK: - Root View with Auth State

struct RootView: View {
    @ObservedObject var authModel: AuthModel

    var body: some View {
        Group {
            switch authModel.authState {
            case .loading:
                LoadingView()
            case .unauthenticated:
                LoginView(authModel: authModel)
            case .authenticated(_):
                ContentView()
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AppTheme.actionBlue)

                Text("Loading...")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - AppDelegate for Orientation Control

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowedOrientations
    }
}
