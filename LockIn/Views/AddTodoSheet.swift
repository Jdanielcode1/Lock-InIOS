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
            VStack(spacing: 0) {
                List {
                    // Header Section
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Color.accentColor)

                            Text("New To-Do")
                                .font(.title2.bold())

                            Text("What do you need to do?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowBackground(Color.clear)
                    }

                    // Input Section
                    Section {
                        TextField("e.g., Complete chapter 5", text: $title)
                            .font(.body)
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                if isValid {
                                    createTodo()
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)

                // Add button
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        createTodo()
                    } label: {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add To-Do")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid && !isCreating ? Color.accentColor : Color(UIColor.systemGray4))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || isCreating)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
