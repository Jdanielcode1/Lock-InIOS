//
//  AddSubtaskSheet.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct AddSubtaskSheet: View {
    let goalId: String
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var estimatedHours: Double = 5
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let convexService = ConvexService.shared

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.energyGradient)

                            Text("New Subtask")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Break down your goal into manageable pieces")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            // Title
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                ZStack(alignment: .leading) {
                                    if title.isEmpty {
                                        Text("e.g., Learn SwiftUI basics")
                                            .foregroundColor(.gray)
                                            .padding()
                                    }
                                    TextField("", text: $title)
                                        .textFieldStyle(.plain)
                                        .foregroundColor(.black)
                                        .padding()
                                }
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.smallCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                                        .stroke(AppTheme.lightPurple.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                ZStack(alignment: .topLeading) {
                                    if description.isEmpty {
                                        Text("What will you accomplish?")
                                            .foregroundColor(.gray)
                                            .padding()
                                    }
                                    TextField("", text: $description, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .foregroundColor(.black)
                                        .lineLimit(3...6)
                                        .padding()
                                }
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.smallCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                                        .stroke(AppTheme.lightPurple.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // Estimated Hours
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Estimated Hours")
                                        .font(AppTheme.headlineFont)
                                        .foregroundColor(AppTheme.textPrimary)

                                    Spacer()

                                    Text("\(Int(estimatedHours)) hours")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.energyGradient)
                                }

                                Slider(value: $estimatedHours, in: 1...50, step: 1)
                                    .tint(AppTheme.primaryPurple)

                                HStack {
                                    Text("1 hr")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textSecondary)

                                    Spacer()

                                    Text("50 hrs")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .playfulCard()
                        .padding(.horizontal)

                        // Create Button
                        Button {
                            Task {
                                await createSubtask()
                            }
                        } label: {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Create Subtask")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .primaryButton()
                        .padding(.horizontal)
                        .disabled(title.isEmpty || description.isEmpty || isCreating)
                        .opacity(title.isEmpty || description.isEmpty || isCreating ? 0.6 : 1.0)
                    }
                    .padding(.vertical)
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
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    private func createSubtask() async {
        isCreating = true
        errorMessage = nil

        do {
            _ = try await convexService.createSubtask(
                goalId: goalId,
                title: title,
                description: description,
                estimatedHours: estimatedHours
            )

            dismiss()
        } catch {
            errorMessage = "Failed to create subtask: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

#Preview {
    AddSubtaskSheet(goalId: "123")
}
