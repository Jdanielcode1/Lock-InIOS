//
//  CreateGoalView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct CreateGoalView: View {
    @StateObject private var viewModel: GoalsViewModel
    @StateObject private var todoViewModel = TodoViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var targetHours: Double = 10
    @State private var isCreating = false
    @State private var currentStep = 1
    @State private var addFirstTask = false
    @State private var firstTaskTitle = ""
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isTaskFieldFocused: Bool

    init(viewModel: GoalsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? GoalsViewModel())
    }

    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isFirstTaskValid: Bool {
        !addFirstTask || !firstTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Group {
                if currentStep == 1 {
                    stepOneView
                } else if currentStep == 2 {
                    stepTwoView
                } else {
                    stepThreeView
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if currentStep > 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        if currentStep > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        } else {
                            Text("Cancel")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Goal Name

    var stepOneView: some View {
        VStack(spacing: 0) {
            List {
                // Header Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.secondary)

                        Text("What's your goal?")
                            .font(.title2.bold())

                        Text("Give your goal a name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }

                // Input Section
                Section {
                    TextField("e.g., Learn Swift", text: $title)
                        .font(.body)
                        .focused($isTextFieldFocused)
                        .submitLabel(.continue)
                        .onSubmit {
                            if isTitleValid {
                                goToStepTwo()
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)

            // Continue button
            VStack(spacing: 0) {
                Divider()

                Button {
                    goToStepTwo()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isTitleValid ? Color(UIColor.systemGray4) : Color(UIColor.systemGray5))
                    .foregroundStyle(isTitleValid ? .primary : .secondary)
                    .cornerRadius(12)
                }
                .disabled(!isTitleValid)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Step 2: Target Hours

    var stepTwoView: some View {
        VStack(spacing: 0) {
            List {
                // Header Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.secondary)

                        Text("How many hours?")
                            .font(.title2.bold())

                        Text("Set your target for \"\(title)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }

                // Hours Display
                Section {
                    VStack(spacing: 8) {
                        Text("\(Int(targetHours))")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: targetHours)

                        Text("hours")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                // Slider Section
                Section {
                    VStack(spacing: 16) {
                        Slider(value: $targetHours, in: 1...100, step: 1)

                        // Quick select buttons
                        HStack(spacing: 10) {
                            ForEach([5, 10, 20, 50], id: \.self) { hours in
                                Button {
                                    withAnimation(.snappy) {
                                        targetHours = Double(hours)
                                    }
                                } label: {
                                    Text("\(hours)h")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Int(targetHours) == hours ? .white : Color.accentColor)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Int(targetHours) == hours
                                                ? Color.accentColor
                                                : Color.accentColor.opacity(0.12)
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)

            // Continue button
            VStack(spacing: 0) {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 3
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.systemGray4))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Step 3: First Task (Optional)

    var stepThreeView: some View {
        VStack(spacing: 0) {
            List {
                // Header Section
                Section {
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "checklist")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(.secondary)

                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundStyle(.yellow)
                                .offset(x: 8, y: -4)
                        }

                        Text("Add your first task?")
                            .font(.title2.bold())

                        Text("Break down \"\(title)\" into actionable steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }

                // Toggle Section
                Section {
                    Toggle(isOn: $addFirstTask.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Add a task")
                        }
                    }

                    if addFirstTask {
                        TextField("e.g., Complete chapter 1", text: $firstTaskTitle)
                            .font(.body)
                            .focused($isTaskFieldFocused)
                            .submitLabel(.done)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } footer: {
                    if addFirstTask {
                        Text("You can add more tasks later from the goal details.")
                    } else {
                        Text("Starting with a task helps you get going right away.")
                    }
                }

                // Tip Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 40, height: 40)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stay accountable")
                                .font(.subheadline.bold())

                            Text("Record yourself completing tasks to track real progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)

            // Create button
            VStack(spacing: 0) {
                Divider()

                VStack(spacing: 12) {
                    Button {
                        createGoalWithTask()
                    } label: {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(addFirstTask ? "Create Goal & Task" : "Create Goal")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isCreating || (addFirstTask && !isFirstTaskValid) ? Color(UIColor.systemGray5) : AppTheme.accentGreen)
                        .foregroundStyle(isCreating || (addFirstTask && !isFirstTaskValid) ? Color.secondary : Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(isCreating || (addFirstTask && !isFirstTaskValid))

                    if !addFirstTask {
                        Button {
                            createGoalWithTask()
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(isCreating)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .onChange(of: addFirstTask) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTaskFieldFocused = true
                }
            }
        }
    }

    private func goToStepTwo() {
        isTextFieldFocused = false
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 2
        }
    }

    private func createGoalWithTask() {
        isCreating = true

        Task {
            // Create the goal and get its ID
            if let goalId = await viewModel.createGoalReturningId(
                title: title.trimmingCharacters(in: .whitespaces),
                description: "",
                targetHours: targetHours
            ) {
                // If user wants to add first task, create it
                if addFirstTask && !firstTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    await todoViewModel.createGoalTodo(
                        goalId: goalId,
                        title: firstTaskTitle.trimmingCharacters(in: .whitespaces),
                        description: nil,
                        todoType: .simple,
                        estimatedHours: nil,
                        frequency: .none
                    )
                }
            }

            isCreating = false
            dismiss()
        }
    }
}

#Preview {
    CreateGoalView(viewModel: GoalsViewModel())
}
