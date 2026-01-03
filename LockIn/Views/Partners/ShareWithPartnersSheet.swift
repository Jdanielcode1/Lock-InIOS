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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                    }

                    Text("Share with Partners?")
                        .font(.title2.bold())

                    Text("Let your accountability partners see this session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                // Partners list
                if viewModel.partners.isEmpty {
                    VStack(spacing: 12) {
                        Text("No partners yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Add accountability partners to share your progress")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    List {
                        Section {
                            ForEach(viewModel.partners) { partner in
                                Button {
                                    togglePartner(partner)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Avatar
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.15))
                                                .frame(width: 40, height: 40)

                                            Text(partner.initials)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(partner.displayName)
                                                .font(.body)
                                                .foregroundStyle(.primary)

                                            Text(partner.partnerEmail)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        // Selection indicator
                                        Image(systemName: selectedPartnerIds.contains(partner.partnerId) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 24))
                                            .foregroundStyle(selectedPartnerIds.contains(partner.partnerId) ? .green : Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Text("Select Partners")
                                Spacer()
                                if viewModel.partners.count > 1 {
                                    Button(selectedPartnerIds.count == viewModel.partners.count ? "Deselect All" : "Select All") {
                                        if selectedPartnerIds.count == viewModel.partners.count {
                                            selectedPartnerIds.removeAll()
                                        } else {
                                            selectedPartnerIds = Set(viewModel.partners.map { $0.partnerId })
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        shareWithPartners()
                    } label: {
                        HStack(spacing: 8) {
                            if isSharing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Share with \(selectedPartnerIds.count) Partner\(selectedPartnerIds.count == 1 ? "" : "s")")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedPartnerIds.isEmpty || isSharing ? Color(UIColor.systemGray5) : Color.green)
                        .foregroundStyle(selectedPartnerIds.isEmpty || isSharing ? Color.secondary : Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(selectedPartnerIds.isEmpty || isSharing)

                    Button {
                        onSkip()
                        dismiss()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isSharing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
            // Pre-select all partners by default
            selectedPartnerIds = Set(viewModel.partners.map { $0.partnerId })
        }
    }

    private func togglePartner(_ partner: Partner) {
        if selectedPartnerIds.contains(partner.partnerId) {
            selectedPartnerIds.remove(partner.partnerId)
        } else {
            selectedPartnerIds.insert(partner.partnerId)
        }
    }

    private func shareWithPartners() {
        guard !selectedPartnerIds.isEmpty else { return }

        isSharing = true
        onShare(Array(selectedPartnerIds))
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
