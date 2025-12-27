//
//  AddTodoSheet.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI

struct AddTodoSheet: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var isCreating = false

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "clipboard.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppTheme.primaryGradient)
                                .padding(.top, 20)

                            Text("New To-Do")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Add a task to your list")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form
                        VStack(spacing: 24) {
                            // Title field
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Title")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .textCase(.uppercase)

                                TextField("e.g., Complete chapter 5", text: $title)
                                    .textFieldStyle(PlayfulTextFieldStyle())
                            }

                            // Description field (optional)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 4) {
                                    Text("Description")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .textCase(.uppercase)

                                    Text("(Optional)")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                                }

                                TextField("Add more details...", text: $description, axis: .vertical)
                                    .textFieldStyle(PlayfulTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                        }
                        .padding(20)
                        .playfulCard()

                        // Create button
                        Button {
                            createTodo()
                        } label: {
                            HStack(spacing: 10) {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Add To-Do")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundColor(.white)
                            .background(
                                Group {
                                    if isValid && !isCreating {
                                        AppTheme.primaryGradient
                                    } else {
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                }
                            )
                            .cornerRadius(16)
                            .shadow(color: isValid ? AppTheme.actionBlue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isValid || isCreating)
                        .animation(.easeInOut(duration: 0.2), value: isValid)
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
                    .foregroundColor(AppTheme.actionBlue)
                }
            }
        }
    }

    private func createTodo() {
        isCreating = true

        Task {
            await viewModel.createTodo(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
            )
            isCreating = false
            dismiss()
        }
    }
}

#Preview {
    AddTodoSheet(viewModel: TodoViewModel())
}
