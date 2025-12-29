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
    @FocusState private var titleFocused: Bool

    private let convexService = ConvexService.shared

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
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

                            Text("New Subtask")
                                .font(.title2.bold())

                            Text("Break down your goal into manageable pieces")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }

                    // Title Section
                    Section {
                        TextField("e.g., Learn SwiftUI basics", text: $title)
                            .focused($titleFocused)
                    } header: {
                        Text("Title")
                    }

                    // Description Section
                    Section {
                        TextField("What will you accomplish?", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Description")
                    }

                    // Hours Section
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Hours")
                                Spacer()
                                Text("\(Int(estimatedHours)) hours")
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                            }

                            Slider(value: $estimatedHours, in: 1...50, step: 1)

                            HStack {
                                Text("1 hr")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("50 hrs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Estimated Time")
                    }
                }
                .listStyle(.insetGrouped)

                // Create button
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        Task {
                            await createSubtask()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Subtask")
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                titleFocused = true
            }
        }
    }

    private func createSubtask() async {
        isCreating = true
        errorMessage = nil

        do {
            _ = try await convexService.createSubtask(
                goalId: goalId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
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
