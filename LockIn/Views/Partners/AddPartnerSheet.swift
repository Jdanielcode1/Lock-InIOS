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
    @State private var isPresented = false
    @FocusState private var isEmailFocused: Bool

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        return trimmed.wholeMatch(of: emailRegex) != nil
    }

    private var hasAtSymbol: Bool {
        email.contains("@")
    }

    private var validationMessage: String {
        if email.isEmpty {
            return "Enter your partner's email to get started"
        } else if isValidEmail {
            return "Looking good! Ready to send"
        } else if hasAtSymbol {
            return "Almost there..."
        } else {
            return "Keep typing..."
        }
    }

    var body: some View {
        NavigationView {
            List {
                // Header with animated illustration
                Section {
                    InviteHeaderView(isPresented: $isPresented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // Email input with validation
                Section {
                    HStack(spacing: 12) {
                        TextField("partner@email.com", text: $email)
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

                        // Validation indicator
                        if !email.isEmpty {
                            if isValidEmail {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .animation(.smooth, value: isValidEmail)
                } header: {
                    Text("Email Address")
                } footer: {
                    HStack(spacing: 6) {
                        if isValidEmail {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                        }
                        Text(validationMessage)
                            .foregroundStyle(isValidEmail ? .green : .secondary)
                    }
                    .animation(.smooth, value: validationMessage)
                }

                // Benefits section with icon cards
                Section {
                    BenefitRow(
                        icon: "heart.circle.fill",
                        iconGradient: [.pink, .red],
                        title: "Stay Motivated",
                        subtitle: "See each other's wins and cheer each other on"
                    )

                    BenefitRow(
                        icon: "video.circle.fill",
                        iconGradient: [.green, .mint],
                        title: "Share Sessions",
                        subtitle: "Send recordings of your best study sessions"
                    )

                    BenefitRow(
                        icon: "lock.circle.fill",
                        iconGradient: [.blue, .cyan],
                        title: "Private & Secure",
                        subtitle: "Only share what you choose to share"
                    )
                } header: {
                    Text("Why Add a Partner?")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Invite Partner")
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
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isValidEmail || isSending)
                }
            }
        }
        .onAppear {
            withAnimation(.smooth.delay(0.1)) {
                isPresented = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isEmailFocused = true
            }
        }
    }

    private func sendInvite() {
        guard isValidEmail else { return }

        HapticFeedback.medium()
        isSending = true

        Task {
            let success = await viewModel.sendInvite(email: email.trimmingCharacters(in: .whitespaces).lowercased())

            await MainActor.run {
                isSending = false
                if success {
                    HapticFeedback.success()
                    dismiss()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }
}

// MARK: - Invite Header View

private struct InviteHeaderView: View {
    @Binding var isPresented: Bool
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 88, height: 88)
                    .scaleEffect(isPulsing ? 1.1 : 0.95)
                    .opacity(isPulsing ? 0.5 : 0.8)

                // Main icon circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .accentColor.opacity(0.25), radius: 16, y: 8)
            .scaleUp(isPresented: isPresented)

            // Text content
            VStack(spacing: 6) {
                Text("Invite a Partner")
                    .font(.title2.weight(.bold))
                    .slideUp(isPresented: isPresented, delay: 0.1)

                Text("Accountability is better together")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .slideUp(isPresented: isPresented, delay: 0.15)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            // Gradient icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconGradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddPartnerSheet(viewModel: PartnersViewModel())
}
