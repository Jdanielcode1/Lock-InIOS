//
//  PartnersView.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct PartnersView: View {
    @StateObject private var viewModel = PartnersViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showingAddPartner = false
    @State private var showingInvites = false
    @State private var isPresented = false
    @State private var partnerToRemove: Partner?
    @State private var showingRemoveConfirmation = false

    var body: some View {
        NavigationView {
            List {
                // Pending invites banner (if any)
                if !viewModel.receivedInvites.isEmpty {
                    Section {
                        Button {
                            HapticFeedback.light()
                            showingInvites = true
                        } label: {
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
                                    Text("\(viewModel.receivedInvites.count) Pending Invite\(viewModel.receivedInvites.count == 1 ? "" : "s")")
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
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }

                // Active partners section
                Section {
                    if viewModel.partners.isEmpty && viewModel.sentInvites.isEmpty {
                        PartnersEmptyState(showingAddPartner: $showingAddPartner)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(viewModel.partners) { partner in
                            NavigationLink(destination: PartnerActivityView(partner: partner)) {
                                PartnerRow(partner: partner)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    HapticFeedback.warning()
                                    partnerToRemove = partner
                                    showingRemoveConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }
                } header: {
                    if !viewModel.partners.isEmpty {
                        Text("My Partners")
                    }
                }

                // Pending sent invites section
                if !viewModel.sentInvites.isEmpty {
                    Section {
                        ForEach(viewModel.sentInvites) { invite in
                            SentInviteRow(invite: invite)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        HapticFeedback.light()
                                        Task {
                                            await viewModel.cancelInvite(invite)
                                        }
                                    } label: {
                                        Label("Cancel", systemImage: "xmark")
                                    }
                                }
                        }
                    } header: {
                        Text("Pending Invites Sent")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Partners")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showingAddPartner = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingAddPartner) {
                AddPartnerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingInvites) {
                PartnerInvitesView(viewModel: viewModel)
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
                Text("Are you sure you want to remove \(partner.displayName) as your accountability partner? You won't be able to see their shared sessions anymore.")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
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

// MARK: - Partner Row

struct PartnerRow: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 14) {
            // Gradient avatar
            PartnerAvatar(partner: partner, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(partner.displayName)
                    .font(.body.weight(.medium))

                Text(partner.partnerEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Sent Invite Row

struct SentInviteRow: View {
    let invite: PartnerInvite

    var body: some View {
        HStack(spacing: 14) {
            // Invite avatar with animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(UIColor.tertiarySystemFill),
                                Color(UIColor.quaternarySystemFill)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(invite.toEmail)
                    .font(.body)
                    .lineLimit(1)

                Text(invite.expiryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
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
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct PartnersEmptyState: View {
    @Binding var showingAddPartner: Bool
    @State private var isAnimating = false

    private let circleCount = 3

    var body: some View {
        VStack(spacing: 20) {
            // Animated concentric circles
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

                // Center icon
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

            // Text content
            VStack(spacing: 8) {
                Text("Better Together")
                    .font(.title3.weight(.semibold))

                Text("Invite friends to stay accountable.\nShare your wins and motivate each other.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // CTA Button
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

#Preview {
    PartnersView()
}

#Preview("Empty State") {
    PartnersEmptyState(showingAddPartner: .constant(false))
        .padding()
}
