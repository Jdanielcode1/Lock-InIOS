//
//  LockInApp.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI
import ConvexMobile
import FirebaseCore
import GoogleSignIn

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
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch authModel.authState {
            case .loading:
                LoadingView()
            case .unauthenticated:
                LoginView(authModel: authModel)
            case .authenticated(_):
                ContentView()
                    .environmentObject(authModel)
            }
        }
        .withErrorAlerts()  // Global error alert handling
        .preferredColorScheme(appearanceMode.colorScheme)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase == .background {
                // App came back from background - refresh auth to handle expired tokens
                authModel.refreshSessionIfNeeded()
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.accentColor)

                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - AppDelegate for Firebase & Orientation Control

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowedOrientations
    }

    // Handle Google Sign-In URL callback
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
