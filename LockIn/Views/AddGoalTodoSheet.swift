//
//  AddGoalTodoSheet.swift
//  LockIn
//
//  Created by Claude on 29/12/25.
//

import SwiftUI

struct AddGoalTodoSheet: View {
    let goalId: String
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var todoType: GoalTodoType = .simple
    @State private var estimatedHours: Double = 5
    @State private var frequency: TodoFrequency = .none
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private let convexService = ConvexService.shared

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

                            Text("New Task")
                                .font(.title2.bold())

                            Text("Add a task to track within this goal")
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
                        TextField("e.g., Review lecture notes", text: $title)
                            .focused($titleFocused)
                    } header: {
                        Text("Title")
                    }

                    // Description Section
                    Section {
                        TextField("Optional details...", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                    } header: {
                        Text("Description")
                    }

                    // Type Section
                    Section {
                        Picker("Type", selection: $todoType) {
                            ForEach(GoalTodoType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Task Type")
                    } footer: {
                        Text(todoType == .simple ? "Simple checkbox - mark as done when complete" : "Track hours spent on this task")
                    }

                    // Hours Section (only for hours-based)
                    if todoType == .hours {
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

                    // Frequency Section
                    Section {
                        Picker("Repeat", selection: $frequency) {
                            ForEach(TodoFrequency.allCases, id: \.self) { freq in
                                Label(freq.displayName, systemImage: freq.icon)
                                    .tag(freq)
                            }
                        }
                    } header: {
                        Text("Frequency")
                    } footer: {
                        switch frequency {
                        case .none:
                            Text("One-time task")
                        case .daily:
                            Text("Resets automatically at the start of each day")
                        case .weekly:
                            Text("Resets automatically at the start of each week")
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Create button
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        Task {
                            await createGoalTodo()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Task")
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

    private func createGoalTodo() async {
        isCreating = true
        errorMessage = nil

        do {
            _ = try await convexService.createGoalTodo(
                goalId: goalId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                todoType: todoType,
                estimatedHours: todoType == .hours ? estimatedHours : nil,
                frequency: frequency
            )

            dismiss()
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

#Preview {
    AddGoalTodoSheet(goalId: "123")
}
