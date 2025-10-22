//
//  CreateGoalView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct CreateGoalView: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var targetHours = ""
    @State private var isCreating = false

    var isValid: Bool {
        !title.isEmpty && !description.isEmpty && Double(targetHours) != nil && (Double(targetHours) ?? 0) > 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.primaryGradient)
                                .padding(.top, 20)

                            Text("Create New Goal")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Set a goal and track your progress with study videos")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form
                        VStack(spacing: 20) {
                            // Title field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Goal Title", systemImage: "pencil")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                TextField("e.g., Learn Swift", text: $title)
                                    .textFieldStyle(PlayfulTextFieldStyle())
                                    .foregroundColor(.black)
                            }

                            // Description field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Description", systemImage: "text.alignleft")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                TextField("What do you want to achieve?", text: $description, axis: .vertical)
                                    .textFieldStyle(PlayfulTextFieldStyle())
                                    .foregroundColor(.black)
                                    .lineLimit(3...6)
                            }

                            // Target hours field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Target Hours", systemImage: "clock.fill")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                HStack {
                                    TextField("30", text: $targetHours)
                                        .textFieldStyle(PlayfulTextFieldStyle())
                                        .foregroundColor(.black)
                                        .keyboardType(.decimalPad)

                                    Text("hours")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .padding(.trailing)
                                }
                            }
                        }
                        .padding()
                        .playfulCard()

                        // Create button
                        Button {
                            createGoal()
                        } label: {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Create Goal")
                                }
                                .font(AppTheme.headlineFont)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                        .disabled(!isValid || isCreating)
                        .opacity(isValid ? 1.0 : 0.5)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
    }

    private func createGoal() {
        guard let hours = Double(targetHours) else { return }

        isCreating = true

        Task {
            await viewModel.createGoal(
                title: title,
                description: description,
                targetHours: hours
            )
            isCreating = false
            dismiss()
        }
    }
}

// Custom TextField Style
struct PlayfulTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.black)
            .tint(AppTheme.primaryPurple)
            .padding()
            .background(AppTheme.lightPurple.opacity(0.1))
            .cornerRadius(AppTheme.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                    .stroke(AppTheme.primaryPurple.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    CreateGoalView(viewModel: GoalsViewModel())
}
