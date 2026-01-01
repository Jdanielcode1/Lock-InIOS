//
//  PrivacyModeToggle.swift
//  LockIn
//
//  Created by Claude on 01/01/26.
//

import SwiftUI

/// Toggle button that appears in the recorder's top bar for quick privacy mode access.
struct PrivacyModeToggle: View {
    @ObservedObject var privacyManager: PrivacyModeManager
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: privacyManager.privacyLevel.icon)
                    .font(.system(size: 14, weight: .semibold))

                if privacyManager.privacyLevel != .off {
                    Circle()
                        .fill(privacyManager.isActive ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(privacyManager.privacyLevel != .off ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                privacyManager.privacyLevel != .off
                    ? AppTheme.privacyPurple.opacity(0.9)
                    : Color.black.opacity(0.5)
            )
            .cornerRadius(16)
        }
        .sheet(isPresented: $showingPicker) {
            PrivacyModePickerSheet(privacyManager: privacyManager)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Picker Sheet

struct PrivacyModePickerSheet: View {
    @ObservedObject var privacyManager: PrivacyModeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Privacy Level Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("PRIVACY MODE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(PrivacyLevel.allCases) { level in
                            PrivacyLevelRow(
                                level: level,
                                isSelected: privacyManager.privacyLevel == level,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        privacyManager.privacyLevel = level
                                    }
                                }
                            )

                            if level != PrivacyLevel.allCases.last {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Info text
                VStack(spacing: 8) {
                    Text("Double-tap the screen to show controls")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("You'll feel a gentle vibration every 45s to confirm recording")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
            .navigationTitle("Privacy Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Privacy Level Row

struct PrivacyLevelRow: View {
    let level: PrivacyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppTheme.privacyPurple : Color(UIColor.systemGray5))
                        .frame(width: 32, height: 32)

                    Image(systemName: level.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)

                    Text(level.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.privacyPurple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.privacyPurpleLight : Color.clear)
        }
    }
}

// MARK: - Previews

#Preview("Toggle Button") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            PrivacyModeToggle(privacyManager: {
                let manager = PrivacyModeManager()
                return manager
            }())

            PrivacyModeToggle(privacyManager: {
                let manager = PrivacyModeManager()
                manager.privacyLevel = .stealth
                manager.isActive = true
                return manager
            }())
        }
    }
}

#Preview("Picker Sheet") {
    PrivacyModePickerSheet(privacyManager: PrivacyModeManager())
}
