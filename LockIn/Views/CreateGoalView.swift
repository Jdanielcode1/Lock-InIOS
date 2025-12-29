//
//  CreateGoalView.swift
//  LockIn
//
//  Created by D Cantu on 20/10/25.
//

import SwiftUI

struct CreateGoalView: View {
    @StateObject private var viewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var targetHours: Double = 10
    @State private var isCreating = false
    @State private var currentStep = 1
    @FocusState private var isTextFieldFocused: Bool

    init(viewModel: GoalsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? GoalsViewModel())
    }

    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Group {
                if currentStep == 1 {
                    stepOneView
                } else {
                    stepTwoView
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if currentStep == 2 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        if currentStep == 2 {
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
                            .foregroundStyle(Color.accentColor)

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
                    .background(isTitleValid ? Color.accentColor : Color(UIColor.systemGray4))
                    .foregroundStyle(.white)
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
                            .foregroundStyle(Color.accentColor)

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

            // Create button
            VStack(spacing: 0) {
                Divider()

                Button {
                    createGoal()
                } label: {
                    HStack(spacing: 8) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create Goal")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isCreating)
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

    private func goToStepTwo() {
        isTextFieldFocused = false
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 2
        }
    }

    private func createGoal() {
        isCreating = true

        Task {
            await viewModel.createGoal(
                title: title.trimmingCharacters(in: .whitespaces),
                description: "",
                targetHours: targetHours
            )
            isCreating = false
            dismiss()
        }
    }
}

#Preview {
    CreateGoalView(viewModel: GoalsViewModel())
}
