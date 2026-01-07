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
    @StateObject private var deepLinkManager = DeepLinkManager.shared

    var body: some Scene {
        WindowGroup {
            RootView(authModel: authModel)
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
        }
    }
}

// MARK: - Deep Link Manager

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    @Published var pendingInviteCode: String?
    @Published var showReferralBanner = false
    @Published var referrerName: String?

    private let pendingCodeKey = "pendingInviteCode"

    private init() {
        // Load any pending invite code from storage
        loadPendingCode()
    }

    /// Handle incoming URL (Universal Link or custom URL scheme)
    func handleURL(_ url: URL) {
        // Parse invite code from URL
        // Expected formats:
        // - https://lockin.app/invite/ABC123
        // - lockin://invite/ABC123

        guard let code = extractInviteCode(from: url) else {
            return
        }

        print("Deep link received with invite code: \(code)")
        pendingInviteCode = code
        savePendingCode(code)
    }

    /// Handle Universal Link via NSUserActivity
    func handleUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }
        handleURL(url)
    }

    /// Extract invite code from URL
    private func extractInviteCode(from url: URL) -> String? {
        // Handle path-based URLs: /invite/{code}
        let pathComponents = url.pathComponents
        if let inviteIndex = pathComponents.firstIndex(of: "invite"),
           inviteIndex + 1 < pathComponents.count {
            return pathComponents[inviteIndex + 1].uppercased()
        }

        // Handle query parameter: ?code={code}
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            return code.uppercased()
        }

        return nil
    }

    /// Process pending invite code after user signs up/in
    @MainActor
    func processPendingReferral() async {
        guard let code = pendingInviteCode else { return }

        do {
            let result = try await ConvexService.shared.registerReferral(inviteCode: code)

            switch result.status {
            case "success":
                referrerName = result.referrerName
                showReferralBanner = true
                HapticFeedback.success()
                clearPendingCode()
            case "already_referred", "already_partners":
                // Silently clear - user already has this connection
                clearPendingCode()
            case "invalid_code":
                // Code was invalid - clear it
                clearPendingCode()
            case "self_referral":
                // Can't refer yourself - clear it
                clearPendingCode()
            default:
                break
            }
        } catch {
            print("Failed to process referral: \(error)")
            // Keep the code for retry on next launch
        }
    }

    /// Save pending code to UserDefaults
    private func savePendingCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: pendingCodeKey)
    }

    /// Load pending code from UserDefaults
    private func loadPendingCode() {
        pendingInviteCode = UserDefaults.standard.string(forKey: pendingCodeKey)
    }

    /// Clear pending code
    func clearPendingCode() {
        pendingInviteCode = nil
        UserDefaults.standard.removeObject(forKey: pendingCodeKey)
    }

    /// Dismiss referral banner
    func dismissReferralBanner() {
        showReferralBanner = false
        referrerName = nil
    }
}

// MARK: - Root View with Auth State

struct RootView: View {
    @ObservedObject var authModel: AuthModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.scenePhase) private var scenePhase
    // Use @ObservedObject for singletons - we're observing, not owning
    @ObservedObject private var recordingSession = RecordingSessionManager.shared
    @ObservedObject private var videoPlayerSession = VideoPlayerSessionManager.shared

    var body: some View {
        ZStack {
            Group {
                switch authModel.authState {
                case .loading:
                    LoadingView()
                case .unauthenticated:
                    LoginView(authModel: authModel)
                case .authenticated(_):
                    ContentView()
                        .id("authenticated-content")  // Stable identity prevents recreation on auth state re-emission
                        .environmentObject(authModel)
                        .environmentObject(recordingSession)
                        .environmentObject(videoPlayerSession)
                }
            }

            // Referral success banner (overlays content)
            if deepLinkManager.showReferralBanner {
                ReferralSuccessBanner(
                    referrerName: deepLinkManager.referrerName,
                    onDismiss: { deepLinkManager.dismissReferralBanner() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deepLinkManager.showReferralBanner)
        .withErrorAlerts()  // Global error alert handling
        .preferredColorScheme(appearanceMode.colorScheme)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // App came to foreground - refresh auth session and restart timer
                authModel.appDidBecomeActive()
            } else if newPhase == .background {
                // App went to background - stop refresh timer to save resources
                authModel.appDidEnterBackground()
            }
        }
        .onReceive(authModel.$authState) { newState in
            // Process pending referral when user becomes authenticated
            if case .authenticated = newState {
                Task {
                    await deepLinkManager.processPendingReferral()
                }
            }
        }
        // Recording sessions presented at RootView level to survive auth state changes
        .fullScreenCover(isPresented: $recordingSession.isRecordingActive) {
            RecordingSessionContainer(recordingSession: recordingSession)
        }
        // Video playback sessions presented at RootView level to survive view recreation
        .fullScreenCover(isPresented: $videoPlayerSession.isPlaybackActive) {
            VideoPlayerSessionContainer(videoPlayerSession: videoPlayerSession, recordingSession: recordingSession)
        }
    }
}

// MARK: - Recording Session Container
// Presents the appropriate recorder based on active session type
struct RecordingSessionContainer: View {
    @ObservedObject var recordingSession: RecordingSessionManager
    @StateObject private var todoViewModel = TodoViewModel()

    var body: some View {
        Group {
            if let session = recordingSession.activeSession {
                switch session {
                case .goalSession(let goalId, let goalTodoId, let availableTodos, let continueFrom):
                    TimeLapseRecorderView(goalId: goalId, goalTodoId: goalTodoId, availableTodos: availableTodos, continueFrom: continueFrom)
                        .environmentObject(recordingSession)
                case .goalTodoRecording(let goalTodo, let continueFrom):
                    TimeLapseRecorderView(goalId: goalTodo.goalId, goalTodoId: goalTodo.id, continueFrom: continueFrom)
                        .environmentObject(recordingSession)
                case .todoSession(let todoIds):
                    TodoSessionRecorderView(
                        selectedTodoIds: todoIds,
                        viewModel: todoViewModel,
                        onDismiss: {}
                    )
                    .environmentObject(recordingSession)
                case .todoRecording(let todo):
                    TodoRecorderView(todo: todo, viewModel: todoViewModel)
                        .environmentObject(recordingSession)
                }
            }
        }
    }
}

// MARK: - Video Player Session Container
// Presents the appropriate video player based on active playback session type
struct VideoPlayerSessionContainer: View {
    @ObservedObject var videoPlayerSession: VideoPlayerSessionManager
    @ObservedObject var recordingSession: RecordingSessionManager

    var body: some View {
        Group {
            if let session = videoPlayerSession.activeSession {
                switch session {
                case .studySession(let studySession, let onResume):
                    VideoPlayerView(session: studySession) {
                        // Close video player first, then trigger resume after brief delay
                        // to allow fullScreenCover to dismiss cleanly
                        videoPlayerSession.endPlayback()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onResume?()
                        }
                    }
                    .environmentObject(videoPlayerSession)
                case .todoVideo(let todo, let videoURL, let onResume):
                    TodoVideoPlayerView(videoURL: videoURL, todo: todo) {
                        // Close video player first, then trigger resume after brief delay
                        videoPlayerSession.endPlayback()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onResume?()
                        }
                    }
                    .environmentObject(videoPlayerSession)
                case .goalTodoVideo(let goalTodo, let videoURL, let onResume):
                    GoalTodoVideoPlayerView(videoURL: videoURL, goalTodo: goalTodo) {
                        // Close video player first, then trigger resume after brief delay
                        videoPlayerSession.endPlayback()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onResume?()
                        }
                    }
                    .environmentObject(videoPlayerSession)
                }
            }
        }
    }
}

// MARK: - Referral Success Banner

struct ReferralSuccessBanner: View {
    let referrerName: String?
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're Connected!")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let name = referrerName {
                            Text("You and \(name) are now accountability partners")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("You're now connected with your partner")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 60) // Account for safe area

            Spacer()
        }
        .onAppear {
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                onDismiss()
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
        // Check if it's an invite link first
        if url.scheme == "lockin" || url.path.contains("/invite/") {
            DeepLinkManager.shared.handleURL(url)
            return true
        }
        return GIDSignIn.sharedInstance.handle(url)
    }

    // Handle Universal Links (HTTPS links)
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        DeepLinkManager.shared.handleUserActivity(userActivity)
        return true
    }
}
