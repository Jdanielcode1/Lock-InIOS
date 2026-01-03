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

    var body: some View {
        NavigationView {
            List {
                // Pending invites banner (if any)
                if !viewModel.receivedInvites.isEmpty {
                    Section {
                        Button {
                            showingInvites = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "envelope.badge")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.receivedInvites.count) Pending Invite\(viewModel.receivedInvites.count == 1 ? "" : "s")")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("Tap to review")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Active partners section
                Section {
                    if viewModel.partners.isEmpty && viewModel.sentInvites.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.secondary)

                            Text("No Partners Yet")
                                .font(.headline)

                            Text("Invite friends to stay accountable together")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                showingAddPartner = true
                            } label: {
                                Text("Invite Partner")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.accentColor)
                                    .cornerRadius(20)
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.partners) { partner in
                            NavigationLink(destination: PartnerActivityView(partner: partner)) {
                                PartnerRow(partner: partner)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removePartner(partner)
                                    }
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
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.tertiarySystemFill))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "paperplane")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(invite.toEmail)
                                        .font(.body)

                                    Text(invite.expiryDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("Pending")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
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
                        showingAddPartner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPartner) {
                AddPartnerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingInvites) {
                PartnerInvitesView(viewModel: viewModel)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct PartnerRow: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(partner.initials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.displayName)
                    .font(.body)

                Text("Active partner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PartnersView()
}
