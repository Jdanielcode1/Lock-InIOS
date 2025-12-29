//
//  SettingsView.swift
//  LockIn
//
//  Created by Claude on 25/12/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var showingLogoutAlert = false

    // iPad adaptation
    @Environment(\.horizontalSizeClass) var sizeClass
    private var sizing: AdaptiveSizing {
        AdaptiveSizing(horizontalSizeClass: sizeClass)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: sizing.sectionSpacing) {
                        // App Info Card
                        appInfoCard

                        // Account
                        accountSection

                        // Preferences
                        preferencesSection

                        // Storage
                        storageSection

                        // Archive
                        archiveSection

                        // About
                        aboutSection
                    }
                    .padding(.horizontal, sizing.horizontalPadding)
                    .padding(.vertical)
                    .padding(.bottom, 100)
                    .frame(maxWidth: sizing.maxContentWidth)
                    .frame(maxWidth: .infinity) // Center on iPad
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

    var appInfoCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("Lock In")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("Version 1.0.0")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ACCOUNT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            Button {
                showingLogoutAlert = true
            } label: {
                SettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: .red,
                    title: "Sign Out",
                    value: ""
                )
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PREFERENCES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.fill",
                    iconColor: AppTheme.actionBlue,
                    title: "Notifications",
                    isOn: $notificationsEnabled
                )

                Divider().padding(.leading, 52)

                SettingsToggleRow(
                    icon: "moon.fill",
                    iconColor: AppTheme.actionBlue,
                    title: "Dark Mode",
                    isOn: $darkMode
                )

                Divider().padding(.leading, 52)

                SettingsToggleRow(
                    icon: "hand.tap.fill",
                    iconColor: AppTheme.warningAmber,
                    title: "Haptic Feedback",
                    isOn: $hapticFeedback
                )
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    var storageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STORAGE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "Videos Storage",
                    value: calculateStorageSize()
                )

                Divider().padding(.leading, 52)

                Button {
                    // Clear cache action
                } label: {
                    SettingsRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "Clear Cache",
                        value: ""
                    )
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    var archiveSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ARCHIVE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            NavigationLink(destination: ArchivedItemsView()) {
                SettingsRow(
                    icon: "archivebox.fill",
                    iconColor: .purple,
                    title: "Archived Items",
                    value: "",
                    showChevron: true
                )
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ABOUT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Button {
                    // Privacy policy
                } label: {
                    SettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .green,
                        title: "Privacy Policy",
                        value: "",
                        showChevron: true
                    )
                }

                Divider().padding(.leading, 52)

                Button {
                    // Terms of service
                } label: {
                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: .orange,
                        title: "Terms of Service",
                        value: "",
                        showChevron: true
                    )
                }

                Divider().padding(.leading, 52)

                Button {
                    // Send feedback
                } label: {
                    SettingsRow(
                        icon: "envelope.fill",
                        iconColor: AppTheme.actionBlue,
                        title: "Send Feedback",
                        value: "",
                        showChevron: true
                    )
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.smallCornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
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
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .cornerRadius(8)

            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(AppTheme.actionBlue)
        }
        .padding()
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .cornerRadius(8)

            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
