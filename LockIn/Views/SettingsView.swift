//
//  SettingsView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI
import ConvexMobile

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var showingLogoutAlert = false
    @State private var userEmail: String?
    @State private var authStatus: String = "Checking..."
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @EnvironmentObject private var authModel: AuthModel
    @Binding var selectedTab: Tab

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
                } header: {
                    Text("Account")
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
                    HStack {
                        Label("Videos Storage", systemImage: "folder.fill")
                        Spacer()
                        Text(calculateStorageSize())
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        // Clear cache action
                    } label: {
                        Label("Clear Cache", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Storage")
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
                    Button {
                        // Privacy policy
                    } label: {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Button {
                        // Terms of service
                    } label: {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                    }

                    Button {
                        // Send feedback
                    } label: {
                        HStack {
                            Label("Send Feedback", systemImage: "envelope.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
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
                        selectedTab = .goals
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
                        await convexClient.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
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
    SettingsView(selectedTab: .constant(.settings))
        .environmentObject(TabBarVisibility())
        .environmentObject(AuthModel())
}
