//
//  AddTodoSheet.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI

struct AddTodoSheet: View {
    @ObservedObject var viewModel: TodoViewModel
    @StateObject private var goalsViewModel = GoalsViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var isCreating = false
    @State private var selectedGoal: Goal?
    @State private var showGoalOptions = false
    @State private var todoType: GoalTodoType = .simple
    @State private var estimatedHours: Double = 1
    @State private var frequency: TodoFrequency = .none
    @FocusState private var isTextFieldFocused: Bool

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var buttonText: String {
        if let goal = selectedGoal {
            return "Add to \(goal.title)"
        }
        return "Add To-Do"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    // Header Section
                    Section {
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundStyle(Color.accentColor)

                                if selectedGoal != nil {
                                    Image(systemName: "target")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(Color.green)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: 4)
                                }
                            }

                            Text("New To-Do")
                                .font(.title2.bold())

                            Text("What do you need to do?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }

                    // Title Input Section
                    Section {
                        TextField("e.g., Complete chapter 5", text: $title)
                            .font(.body)
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                if isValid && selectedGoal == nil {
                                    createTodo()
                                }
                            }
                    }

                    // Goal Linking Section
                    Section {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showGoalOptions.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(selectedGoal != nil ? .green : .secondary)

                                Text(selectedGoal?.title ?? "Link to Goal")
                                    .foregroundStyle(selectedGoal != nil ? .primary : .secondary)

                                Spacer()

                                if selectedGoal != nil {
                                    Button {
                                        withAnimation {
                                            selectedGoal = nil
                                            showGoalOptions = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Image(systemName: showGoalOptions ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        if showGoalOptions {
                            if goalsViewModel.goals.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                    Text("No goals yet. Create a goal first to link tasks.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            } else {
                                ForEach(goalsViewModel.goals) { goal in
                                    Button {
                                        withAnimation {
                                            selectedGoal = goal
                                            showGoalOptions = false
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(goal.title)
                                                    .foregroundStyle(.primary)

                                                Text("\(Int(goal.progressPercentage))% complete")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if selectedGoal?.id == goal.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } header: {
                        Text("Link to Goal (Optional)")
                    } footer: {
                        if selectedGoal != nil {
                            Text("This task will appear under your goal and count towards its progress.")
                        }
                    }

                    // Advanced Options (only when goal is selected)
                    if selectedGoal != nil {
                        Section {
                            // Task Type
                            Picker("Type", selection: $todoType) {
                                Text("Simple").tag(GoalTodoType.simple)
                                Text("Track Hours").tag(GoalTodoType.hours)
                            }

                            // Estimated Hours (only for hours type)
                            if todoType == .hours {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Estimated Hours")
                                        Spacer()
                                        Text("\(Int(estimatedHours))h")
                                            .foregroundStyle(.secondary)
                                    }

                                    Slider(value: $estimatedHours, in: 1...20, step: 1)
                                }
                            }

                            // Frequency
                            Picker("Repeat", selection: $frequency) {
                                Text("One-time").tag(TodoFrequency.none)
                                Text("Daily").tag(TodoFrequency.daily)
                                Text("Weekly").tag(TodoFrequency.weekly)
                            }
                        } header: {
                            Text("Task Options")
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
                                Image(systemName: selectedGoal != nil ? "plus.circle.fill" : "plus.circle.fill")
                                Text(buttonText)
                                    .lineLimit(1)
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid && !isCreating ? Color.accentColor : Color(UIColor.systemGray5))
                        .foregroundStyle(isValid && !isCreating ? .white : .secondary)
                        .cornerRadius(12)
                        .shadow(color: isValid && !isCreating ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        Task {
            if let goal = selectedGoal {
                // Create goal-linked todo
                await viewModel.createGoalTodo(
                    goalId: goal.id,
                    title: trimmedTitle,
                    description: nil,
                    todoType: todoType,
                    estimatedHours: todoType == .hours ? estimatedHours : nil,
                    frequency: frequency
                )
            } else {
                // Create standalone todo
                await viewModel.createTodo(
                    title: trimmedTitle,
                    description: nil
                )
            }
            isCreating = false
            dismiss()
        }
    }
}

#Preview {
    AddTodoSheet(viewModel: TodoViewModel())
}
