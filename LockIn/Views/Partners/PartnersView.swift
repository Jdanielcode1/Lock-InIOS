//
//  PartnersView.swift
//  LockIn
//
//  Stories-style partner view with horizontal avatar row
//

import SwiftUI

struct PartnersView: View {
    @StateObject private var viewModel = PartnersViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showingAddPartner = false
    @State private var showingInvites = false
    @State private var showMyStories = false
    @State private var selectedPartner: Partner?
    @State private var partnerToRemove: Partner?
    @State private var showingRemoveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stories row at top
                PartnerStoriesRow(
                    partners: viewModel.partners,
                    hasNewVideos: { _ in false }, // TODO: Track viewed state
                    onTapUser: { showMyStories = true },
                    onTapPartner: { partner in selectedPartner = partner },
                    onTapAdd: { showingAddPartner = true }
                )
                .background(Color(UIColor.systemBackground))

                Divider()
                    .padding(.horizontal, 16)

                // Main content
                VStack(spacing: 20) {
                    // Pending invites banner (if any)
                    if !viewModel.receivedInvites.isEmpty {
                        PendingInvitesBanner(
                            count: viewModel.receivedInvites.count,
                            onTap: { showingInvites = true }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    // Partner list section
                    if viewModel.partners.isEmpty && viewModel.sentInvites.isEmpty {
                        PartnersEmptyState(showingAddPartner: $showingAddPartner)
                            .padding(.top, 20)
                    } else {
                        VStack(spacing: 12) {
                            // Active partners
                            if !viewModel.partners.isEmpty {
                                PartnerListSection(
                                    title: "My Partners",
                                    partners: viewModel.partners,
                                    onTap: { partner in selectedPartner = partner },
                                    onRemove: { partner in
                                        partnerToRemove = partner
                                        showingRemoveConfirmation = true
                                    }
                                )
                            }

                            // Pending sent invites
                            if !viewModel.sentInvites.isEmpty {
                                SentInvitesSection(
                                    invites: viewModel.sentInvites,
                                    onCancel: { invite in
                                        Task { await viewModel.cancelInvite(invite) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, viewModel.receivedInvites.isEmpty ? 16 : 0)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Partners")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.receivedInvites.isEmpty {
                    Button {
                        HapticFeedback.light()
                        showingInvites = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope")
                                .fontWeight(.medium)

                            // Badge
                            Text("\(viewModel.receivedInvites.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 8, y: -6)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPartner) {
            AddPartnerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingInvites) {
            PartnerInvitesView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showMyStories) {
            MyStoriesViewer()
        }
        .fullScreenCover(item: $selectedPartner) { partner in
            PartnerStoryViewer(partner: partner)
        }
        .alert("Remove Partner", isPresented: $showingRemoveConfirmation, presenting: partnerToRemove) { partner in
            Button("Cancel", role: .cancel) {
                partnerToRemove = nil
            }
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.removePartner(partner)
                    partnerToRemove = nil
                }
            }
        } message: { partner in
            Text("Are you sure you want to remove \(partner.displayName)? You won't see their shared sessions anymore.")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - Pending Invites Banner

private struct PendingInvitesBanner: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onTap()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count) Pending Invite\(count == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Tap to review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}

// MARK: - Partner List Section

private struct PartnerListSection: View {
    let title: String
    let partners: [Partner]
    let onTap: (Partner) -> Void
    let onRemove: (Partner) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                ForEach(partners) { partner in
                    PartnerListRow(partner: partner, onTap: { onTap(partner) })
                        .contextMenu {
                            Button(role: .destructive) {
                                HapticFeedback.warning()
                                onRemove(partner)
                            } label: {
                                Label("Remove Partner", systemImage: "person.badge.minus")
                            }
                        }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Partner List Row

private struct PartnerListRow: View {
    let partner: Partner
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onTap()
        }) {
            HStack(spacing: 14) {
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

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PressButtonStyle(scale: 0.98))
    }
}

// MARK: - Sent Invites Section

private struct SentInvitesSection: View {
    let invites: [PartnerInvite]
    let onCancel: (PartnerInvite) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Invites Sent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 1) {
                ForEach(invites) { invite in
                    SentInviteRow(invite: invite)
                        .contextMenu {
                            Button(role: .destructive) {
                                HapticFeedback.light()
                                onCancel(invite)
                            } label: {
                                Label("Cancel Invite", systemImage: "xmark")
                            }
                        }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Sent Invite Row

private struct SentInviteRow: View {
    let invite: PartnerInvite

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 44, height: 44)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(invite.toEmail)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(invite.expiryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Pending")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

struct PartnersEmptyState: View {
    @Binding var showingAddPartner: Bool
    @State private var isAnimating = false

    private let circleCount = 3

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<circleCount, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.accentColor.opacity(0.3), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 60 + CGFloat(index) * 40, height: 60 + CGFloat(index) * 40)
                        .scaleEffect(isAnimating ? 1.0 : 0.9)
                        .opacity(isAnimating ? 0.6 - Double(index) * 0.15 : 0.3)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: isAnimating
                        )
                }

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                .shadow(color: .accentColor.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.vertical, 8)

            VStack(spacing: 8) {
                Text("Better Together")
                    .font(.title3.weight(.semibold))

                Text("Invite friends to stay accountable.\nShare your wins and motivate each other.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                HapticFeedback.medium()
                showingAddPartner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Invite Partner")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    PartnersView()
}
