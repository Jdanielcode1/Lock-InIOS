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
    @State private var frequency: TodoFrequency = .none
    @State private var isCreating = false
    @FocusState private var titleFocused: Bool

    private let convexService = ConvexService.shared

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                // Title Section
                Section {
                    TextField("What do you need to do?", text: $title)
                        .font(.body)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValid {
                                createTask()
                            }
                        }
                }

                // Repeat Section
                Section {
                    Picker("Repeat", selection: $frequency) {
                        Text("Never").tag(TodoFrequency.none)
                        Text("Daily").tag(TodoFrequency.daily)
                        Text("Weekly").tag(TodoFrequency.weekly)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createTask()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Add")
                                .bold()
                        }
                    }
                    .disabled(!isValid || isCreating)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                titleFocused = true
            }
        }
    }

    private func createTask() {
        guard isValid else { return }

        isCreating = true
        let taskTitle = title.trimmingCharacters(in: .whitespaces)

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        Task {
            do {
                _ = try await convexService.createGoalTodo(
                    goalId: goalId,
                    title: taskTitle,
                    description: nil,
                    todoType: .simple,
                    estimatedHours: nil,
                    frequency: frequency
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            }
        }
    }
}

#Preview {
    AddGoalTodoSheet(goalId: "123")
}
