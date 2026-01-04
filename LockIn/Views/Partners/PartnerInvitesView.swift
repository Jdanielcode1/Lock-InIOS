//
//  PartnerInvitesView.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct PartnerInvitesView: View {
    @ObservedObject var viewModel: PartnersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isPresented = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.receivedInvites.isEmpty {
                        InvitesEmptyState()
                            .slideUp(isPresented: isPresented)
                    } else {
                        // Header
                        VStack(spacing: 4) {
                            Text("\(viewModel.receivedInvites.count) Partner Request\(viewModel.receivedInvites.count == 1 ? "" : "s")")
                                .font(.headline)
                            Text("People who want to stay accountable with you")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        .slideUp(isPresented: isPresented)

                        // Invite cards
                        ForEach(Array(viewModel.receivedInvites.enumerated()), id: \.element.id) { index, invite in
                            InviteCard(invite: invite, viewModel: viewModel)
                                .slideUp(isPresented: isPresented, delay: 0.05 + Double(index) * 0.08)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Partner Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation(.smooth.delay(0.1)) {
                    isPresented = true
                }
            }
        }
    }
}

// MARK: - Invite Card

private struct InviteCard: View {
    let invite: PartnerInvite
    @ObservedObject var viewModel: PartnersViewModel
    @State private var isProcessing = false
    @State private var processingAction: InviteAction?

    enum InviteAction {
        case accept, decline
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with avatar and info
            HStack(spacing: 14) {
                // Avatar
                InviteAvatar(invite: invite, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.senderDisplayName)
                        .font(.headline)

                    Text(invite.fromUserEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Expiry badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(invite.expiryDescription)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                // Decline button
                Button {
                    declineInvite()
                } label: {
                    HStack(spacing: 6) {
                        if isProcessing && processingAction == .decline {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Decline")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.tertiarySystemFill))
                    .foregroundStyle(.primary)
                    .cornerRadius(DesignTokens.cornerRadiusSmall)
                }
                .disabled(isProcessing)
                .buttonStyle(PressButtonStyle(enableHaptic: false))

                // Accept button
                Button {
                    acceptInvite()
                } label: {
                    HStack(spacing: 6) {
                        if isProcessing && processingAction == .accept {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Accept")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(DesignTokens.cornerRadiusSmall)
                }
                .disabled(isProcessing)
                .buttonStyle(PressButtonStyle(enableHaptic: false))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    private func acceptInvite() {
        HapticFeedback.medium()
        isProcessing = true
        processingAction = .accept

        Task {
            await viewModel.acceptInvite(invite)
            await MainActor.run {
                HapticFeedback.success()
                isProcessing = false
                processingAction = nil
            }
        }
    }

    private func declineInvite() {
        HapticFeedback.light()
        isProcessing = true
        processingAction = .decline

        Task {
            await viewModel.declineInvite(invite)
            await MainActor.run {
                isProcessing = false
                processingAction = nil
            }
        }
    }
}

// MARK: - Empty State

private struct InvitesEmptyState: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 2)
                    .frame(width: 88, height: 88)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 0.3 : 0.6)

                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 72, height: 72)

                    Image(systemName: "envelope.open")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("No Pending Invites")
                    .font(.headline)

                Text("When someone invites you to be their\naccountability partner, it will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    PartnerInvitesView(viewModel: PartnersViewModel())
}

#Preview("With Invites") {
    // Note: This would need actual invite data to display properly
    PartnerInvitesView(viewModel: PartnersViewModel())
}
