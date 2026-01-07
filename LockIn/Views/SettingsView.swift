//
//  SettingsView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI
import ConvexMobile
import FirebaseAuth

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingClearCacheAlert = false
    @State private var isDeletingAccount = false
    @State private var isClearingCache = false
    @State private var userEmail: String?
    @State private var authStatus: String = "Checking..."
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @EnvironmentObject private var authModel: AuthModel
    @Binding var selectedTab: Tab

    // URLs for legal pages - replace with your actual URLs
    private let privacyPolicyURL = URL(string: "https://lockinapp.com/privacy")!
    private let termsOfServiceURL = URL(string: "https://lockinapp.com/terms")!
    private let feedbackEmail = "feedback@lockinapp.com"

    var body: some View {
        NavigationView {
            List {
                // App Info Header
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(Color.accentColor)

                        Text("Lock In")
                            .font(.title2.bold())

                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                // Account
                Section {
                    // User info row
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(userEmail != nil ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            if let email = userEmail {
                                Text(email)
                                    .font(.subheadline)

                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                    Text("Signed in")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Text("Not signed in")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(authStatus)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account will permanently remove all your data including goals, sessions, and videos.")
                }

                // Preferences
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                    Picker(selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }

                    Toggle(isOn: $hapticFeedback) {
                        Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    }
                } header: {
                    Text("Preferences")
                }

                // Storage
                Section {
                    NavigationLink {
                        VideoStorageView()
                    } label: {
                        HStack {
                            Label("Manage Videos", systemImage: "folder.fill")
                            Spacer()
                            Text(calculateStorageSize())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        showingClearCacheAlert = true
                    } label: {
                        HStack {
                            Label("Clear Cache", systemImage: "trash.fill")
                            if isClearingCache {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isClearingCache)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing cache will remove cached thumbnails and temporary files. Your videos will not be deleted.")
                }

                // Archive
                Section {
                    NavigationLink {
                        ArchivedItemsView()
                    } label: {
                        Label("Archived Items", systemImage: "archivebox.fill")
                    }
                } header: {
                    Text("Archive")
                }

                // About
                Section {
                    Link(destination: privacyPolicyURL) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Link(destination: termsOfServiceURL) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Button {
                        sendFeedbackEmail()
                    } label: {
                        HStack {
                            Label("Send Feedback", systemImage: "envelope.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedTab = .home
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                            Text("Back")
                        }
                    }
                }
            }
            .onAppear { tabBarVisibility.hide() }
            .onDisappear { tabBarVisibility.show() }
            .task {
                await checkAuthStatus()
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        // Sign out of Firebase first
                        try? Auth.auth().signOut()
                        // Then logout from Convex
                        await convexClient.logout()
                        clearLocalData()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Cache", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear cached thumbnails and temporary files. Your videos will not be deleted.")
            }
        }
        .navigationViewStyle(.stack)
    }

    func calculateStorageSize() -> String {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return "0 MB"
        }

        let videosURL = documentsURL.appendingPathComponent("LockInVideos")

        guard let contents = try? FileManager.default.contentsOfDirectory(at: videosURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }

        var totalSize: Int64 = 0
        for url in contents {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    func checkAuthStatus() async {
        // Subscribe to auth state changes
        for await state in convexClient.authState.values {
            await MainActor.run {
                switch state {
                case .authenticated(let credentials):
                    // Extract email from the ID token (JWT)
                    if let email = extractEmailFromJWT(credentials.idToken) {
                        userEmail = email
                    } else {
                        userEmail = "Authenticated"
                    }
                    authStatus = "Connected"
                case .unauthenticated:
                    userEmail = nil
                    authStatus = "Session expired"
                case .loading:
                    userEmail = nil
                    authStatus = "Loading..."
                }
            }
        }
    }

    func extractEmailFromJWT(_ jwt: String) -> String? {
        // JWT format: header.payload.signature
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else {
            return nil
        }

        return email
    }

    // MARK: - Account Actions

    func deleteAccount() async {
        isDeletingAccount = true

        do {
            // 1. Delete all user data from Convex
            try await ConvexService.shared.deleteAllUserData()

            // 2. Delete local files (videos, thumbnails)
            deleteAllLocalFiles()

            // 3. Clear caches
            await ThumbnailCache.shared.clearAll()

            // 4. Delete Firebase user account
            if let user = Auth.auth().currentUser {
                try await user.delete()
            }

            // 5. Sign out of Firebase (this triggers auth state change)
            try Auth.auth().signOut()

            // 6. Logout from Convex
            await convexClient.logout()

            // 7. Clear local data
            clearLocalData()

            print("Account deleted successfully")
        } catch {
            print("Failed to delete account: \(error)")
            isDeletingAccount = false

            // If Firebase delete fails due to recent login requirement
            if (error as NSError).code == AuthErrorCode.requiresRecentLogin.rawValue {
                ErrorAlertManager.shared.show(.authError("Please sign out and sign back in, then try deleting your account again."))
            } else {
                ErrorAlertManager.shared.show(.unknown("Failed to delete account. Please try again."))
            }
            return
        }

        isDeletingAccount = false
    }

    func clearCache() {
        isClearingCache = true

        Task {
            // Clear thumbnail cache
            await ThumbnailCache.shared.clearAll()

            // Clear temporary files
            let fileManager = FileManager.default
            if let tempDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? fileManager.removeItem(at: tempDir.appendingPathComponent("thumbnails"))
            }

            await MainActor.run {
                isClearingCache = false
            }
        }
    }

    func clearLocalData() {
        // Clear UserDefaults app-specific data (but keep preferences)
        // This is called on logout to clear cached user data
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        UserDefaults.standard.removeObject(forKey: "cachedUserId")
    }

    func deleteAllLocalFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // Delete videos folder
        let videosURL = documentsURL.appendingPathComponent("LockInVideos")
        try? fileManager.removeItem(at: videosURL)

        // Delete thumbnails folder
        let thumbnailsURL = documentsURL.appendingPathComponent("Thumbnails")
        try? fileManager.removeItem(at: thumbnailsURL)

        // Clear caches directory
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: cachesURL)
        }
    }

    func sendFeedbackEmail() {
        let subject = "Lock In App Feedback"
        let body = "App Version: 1.0.0\niOS Version: \(UIDevice.current.systemVersion)\n\nFeedback:\n"

        if let url = URL(string: "mailto:\(feedbackEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#Preview {
    SettingsView(selectedTab: .constant(.me))
        .environmentObject(TabBarVisibility())
        .environmentObject(AuthModel())
}
