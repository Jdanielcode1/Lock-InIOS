//
//  ShareWithPartnersSheet.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct ShareWithPartnersSheet: View {
    let videoURL: URL
    let durationMinutes: Double
    let goalTitle: String?
    let todoTitle: String?
    let onShare: ([String]) -> Void
    let onSkip: () -> Void

    @StateObject private var viewModel = PartnersViewModel()
    @State private var selectedPartnerIds: Set<String> = []
    @State private var isSharing = false
    @State private var isPresented = false
    @State private var showCheckmark = false
    @Environment(\.dismiss) var dismiss

    private var formattedDuration: String {
        let minutes = Int(durationMinutes)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Celebration Header
                CelebrationHeader(
                    isPresented: $isPresented,
                    showCheckmark: $showCheckmark,
                    duration: formattedDuration,
                    goalTitle: goalTitle,
                    todoTitle: todoTitle
                )
                .padding(.top, 20)
                .padding(.horizontal, 20)

                // Partners list
                if viewModel.partners.isEmpty {
                    NoPartnersView()
                        .slideUp(isPresented: isPresented, delay: 0.3)
                } else {
                    List {
                        Section {
                            ForEach(viewModel.partners) { partner in
                                PartnerSelectionRow(
                                    partner: partner,
                                    isSelected: selectedPartnerIds.contains(partner.partnerId)
                                ) {
                                    togglePartner(partner)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Share With")
                                Spacer()
                                if viewModel.partners.count > 1 {
                                    Button(selectedPartnerIds.count == viewModel.partners.count ? "Deselect All" : "Select All") {
                                        HapticFeedback.selection()
                                        withAnimation(.smooth) {
                                            if selectedPartnerIds.count == viewModel.partners.count {
                                                selectedPartnerIds.removeAll()
                                            } else {
                                                selectedPartnerIds = Set(viewModel.partners.map { $0.partnerId })
                                            }
                                        }
                                    }
                                    .font(.caption.weight(.medium))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Share button
                    Button {
                        shareWithPartners()
                    } label: {
                        HStack(spacing: 10) {
                            if isSharing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(selectedPartnerIds.isEmpty ? "Select Partners to Share" : "Share with \(selectedPartnerIds.count) Partner\(selectedPartnerIds.count == 1 ? "" : "s")")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if selectedPartnerIds.isEmpty || isSharing {
                                    Color(UIColor.systemGray5)
                                } else {
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            }
                        )
                        .foregroundStyle(selectedPartnerIds.isEmpty || isSharing ? Color.secondary : Color.white)
                        .cornerRadius(14)
                        .shadow(color: selectedPartnerIds.isEmpty ? .clear : .green.opacity(0.25), radius: 8, y: 4)
                    }
                    .disabled(selectedPartnerIds.isEmpty || isSharing)
                    .buttonStyle(PressButtonStyle(enableHaptic: false))
                    .animation(.smooth, value: selectedPartnerIds.isEmpty)

                    // Skip button
                    Button {
                        onSkip()
                        dismiss()
                    } label: {
                        Text("Keep Private")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .disabled(isSharing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .slideUp(isPresented: isPresented, delay: 0.35)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSkip()
                        dismiss()
                    }
                    .disabled(isSharing)
                }
            }
        }
        .onAppear {
            // Trigger celebration
            HapticFeedback.celebration()

            withAnimation(.smooth) {
                isPresented = true
            }

            // Delay checkmark animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.bouncy) {
                    showCheckmark = true
                }
            }

            // Pre-select all partners by default
            selectedPartnerIds = Set(viewModel.partners.map { $0.partnerId })
        }
    }

    private func togglePartner(_ partner: Partner) {
        HapticFeedback.selection()
        withAnimation(.smooth) {
            if selectedPartnerIds.contains(partner.partnerId) {
                selectedPartnerIds.remove(partner.partnerId)
            } else {
                selectedPartnerIds.insert(partner.partnerId)
            }
        }
    }

    private func shareWithPartners() {
        guard !selectedPartnerIds.isEmpty else { return }

        HapticFeedback.success()
        isSharing = true
        onShare(Array(selectedPartnerIds))
    }
}

// MARK: - Celebration Header

private struct CelebrationHeader: View {
    @Binding var isPresented: Bool
    @Binding var showCheckmark: Bool
    let duration: String
    let goalTitle: String?
    let todoTitle: String?

    @State private var ringPulse = false

    var body: some View {
        VStack(spacing: 16) {
            // Animated checkmark with pulsing ring
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 3)
                    .frame(width: 88, height: 88)
                    .scaleEffect(ringPulse ? 1.15 : 1.0)
                    .opacity(ringPulse ? 0 : 0.8)

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: .green.opacity(0.3), radius: 12, y: 6)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0)
            }
            .scaleUp(isPresented: isPresented)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    ringPulse = true
                }
            }

            // Text content
            VStack(spacing: 8) {
                Text("Session Complete!")
                    .font(.title2.weight(.bold))
                    .slideUp(isPresented: isPresented, delay: 0.1)

                // Session details
                HStack(spacing: 16) {
                    // Duration badge
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text(duration)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.green)

                    // Goal/Todo if present
                    if let title = goalTitle ?? todoTitle {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .slideUp(isPresented: isPresented, delay: 0.15)

                Text("Share your achievement with accountability partners")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .slideUp(isPresented: isPresented, delay: 0.2)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Partner Selection Row

private struct PartnerSelectionRow: View {
    let partner: Partner
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Gradient avatar
                PartnerAvatar(partner: partner, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(partner.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(partner.partnerEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator with animation
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color(UIColor.tertiaryLabel), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.smooth, value: isSelected)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle(scale: 0.98, enableHaptic: false))
    }
}

// MARK: - No Partners View

private struct NoPartnersView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 64, height: 64)

                Image(systemName: "person.2.slash")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("No Partners Yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Add accountability partners from\nthe Partners tab to share sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    ShareWithPartnersSheet(
        videoURL: URL(fileURLWithPath: "/test.mov"),
        durationMinutes: 45,
        goalTitle: "Learn Swift",
        todoTitle: "Complete Chapter 1"
    ) { partnerIds in
        print("Share with: \(partnerIds)")
    } onSkip: {
        print("Skipped")
    }
}

#Preview("Long Session") {
    ShareWithPartnersSheet(
        videoURL: URL(fileURLWithPath: "/test.mov"),
        durationMinutes: 125,
        goalTitle: nil,
        todoTitle: nil
    ) { _ in } onSkip: { }
}
