//
//  LoginView.swift
//  LockIn
//
//  Login screen with Apple, Google, and Guest sign-in options
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authModel: AuthModel

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App Icon/Logo
                Image(systemName: "lock.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(Color.accentColor)

                // App Title
                VStack(spacing: 8) {
                    Text("Lock In")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Text("Track your goals with video proof")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sign-in Buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    Button(action: authModel.signInWithApple) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                            Text("Sign in with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.black)
                        .cornerRadius(14)
                    }

                    // Sign in with Google
                    Button(action: authModel.signInWithGoogle) {
                        HStack(spacing: 12) {
                            GoogleLogo()
                            Text("Sign in with Google")
                                .font(.headline)
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                    }

                    // Continue as Guest
                    Button(action: authModel.signInAnonymously) {
                        Text("Continue as Guest")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                // Error Message
                if let error = authModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Footer
                Text("Your data syncs securely across devices")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Google Logo
struct GoogleLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
            Text("G")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .green, .yellow, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
