//
//  AddPartnerSheet.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct AddPartnerSheet: View {
    @ObservedObject var viewModel: PartnersViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var isSending = false
    @FocusState private var isEmailFocused: Bool

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        return trimmed.wholeMatch(of: emailRegex) != nil
    }

    var body: some View {
        NavigationView {
            List {
                // Header
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Color.accentColor)
                        }

                        Text("Invite a Partner")
                            .font(.title2.bold())

                        Text("Share your progress and stay accountable together")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }

                // Email input
                Section {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isEmailFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if isValidEmail {
                                sendInvite()
                            }
                        }
                } footer: {
                    Text("Enter your partner's email address. They'll receive an invite to connect with you.")
                }

                // What they'll see
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shared Videos")
                                .font(.subheadline.bold())

                            Text("Your partner can view study sessions you share with them")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Privacy")
                                .font(.subheadline.bold())

                            Text("Only videos you explicitly share are visible to partners")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sendInvite()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .bold()
                        }
                    }
                    .disabled(!isValidEmail || isSending)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isEmailFocused = true
            }
        }
    }

    private func sendInvite() {
        guard isValidEmail else { return }

        isSending = true

        Task {
            let success = await viewModel.sendInvite(email: email.trimmingCharacters(in: .whitespaces).lowercased())

            await MainActor.run {
                isSending = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AddPartnerSheet(viewModel: PartnersViewModel())
}
