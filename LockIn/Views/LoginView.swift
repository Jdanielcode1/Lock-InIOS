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
            // Background
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Icon/Logo
                Image(systemName: "lock.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.primaryGradient)

                // App Title
                VStack(spacing: 8) {
                    Text("Lock In")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Track your goals with video proof")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Login Button
                Button(action: authModel.login) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                        Text("Sign In")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)

                // Footer
                Text("Secure authentication powered by Auth0")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 40)
            }
        }
    }
}
