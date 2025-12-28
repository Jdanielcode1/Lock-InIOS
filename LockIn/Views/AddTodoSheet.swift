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
    @State private var isCreating = false
    @FocusState private var isTextFieldFocused: Bool

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 56))
                                    .foregroundStyle(AppTheme.primaryGradient)
                                    .padding(.top, 40)

                                Text("New To-Do")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("What do you need to do?")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            // Text field
                            TextField("e.g., Complete chapter 5", text: $title)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .padding(.horizontal, 8)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isTextFieldFocused ? AppTheme.actionBlue : AppTheme.borderLight, lineWidth: isTextFieldFocused ? 2 : 1.5)
                                )
                                .shadow(color: isTextFieldFocused ? AppTheme.actionBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 24)
                                .focused($isTextFieldFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    if isValid {
                                        createTodo()
                                    }
                                }
                        }
                        .padding(.bottom, 100)
                    }

                    Spacer()

                    // Sticky create button
                    VStack(spacing: 0) {
                        Divider()

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
                                isValid && !isCreating
                                    ? AnyShapeStyle(AppTheme.primaryGradient)
                                    : AnyShapeStyle(Color.gray.opacity(0.3))
                            )
                            .cornerRadius(16)
                            .shadow(color: isValid ? AppTheme.actionBlue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isValid || isCreating)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.background)
                    }
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }

    private func createTodo() {
        isCreating = true

        Task {
            await viewModel.createTodo(
                title: title.trimmingCharacters(in: .whitespaces),
                description: nil
            )
            isCreating = false
            dismiss()
        }
    }
}

#Preview {
    AddTodoSheet(viewModel: TodoViewModel())
}
