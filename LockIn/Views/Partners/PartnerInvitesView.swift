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

    var body: some View {
        NavigationView {
            List {
                if viewModel.receivedInvites.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)

                        Text("No Pending Invites")
                            .font(.headline)

                        Text("Partner invites will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.receivedInvites) { invite in
                        InviteRow(invite: invite, viewModel: viewModel)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Partner Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InviteRow: View {
    let invite: PartnerInvite
    @ObservedObject var viewModel: PartnersViewModel
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(String(invite.senderDisplayName.prefix(2)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.senderDisplayName)
                        .font(.headline)

                    Text(invite.fromUserEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(invite.expiryDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    declineInvite()
                } label: {
                    Text("Decline")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)

                Button {
                    acceptInvite()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    } else {
                        Text("Accept")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
    }

    private func acceptInvite() {
        isProcessing = true
        Task {
            await viewModel.acceptInvite(invite)
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func declineInvite() {
        isProcessing = true
        Task {
            await viewModel.declineInvite(invite)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

#Preview {
    PartnerInvitesView(viewModel: PartnersViewModel())
}
