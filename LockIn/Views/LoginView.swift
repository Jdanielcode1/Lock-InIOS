//
//  LoginView.swift
//  LockIn
//
//  Created by Claude on 27/12/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authModel: AuthModel

    var body: some View {
        ZStack {
            // Background - adaptive for light/dark mode
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 40) {
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

                // Login Button
                Button(action: authModel.login) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                        Text("Sign In")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                // Footer
                Text("Secure authentication powered by Auth0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
        }
    }
}
