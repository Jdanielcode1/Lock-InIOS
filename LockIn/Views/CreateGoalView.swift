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
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if currentStep == 1 {
                    stepOneView
                } else {
                    stepTwoView
                }
            }
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
                            .foregroundColor(AppTheme.actionBlue)
                        } else {
                            Text("Cancel")
                                .foregroundColor(AppTheme.actionBlue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Goal Name

    var stepOneView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 56))
                            .foregroundStyle(AppTheme.primaryGradient)
                            .padding(.top, 40)

                        Text("What's your goal?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Give your goal a name")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    // Text field
                    TextField("e.g., Learn Swift", text: $title)
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
                        .submitLabel(.continue)
                        .onSubmit {
                            if isTitleValid {
                                goToStepTwo()
                            }
                        }
                }
                .padding(.bottom, 100)
            }

            Spacer()

            // Sticky continue button
            VStack(spacing: 0) {
                Divider()

                Button {
                    goToStepTwo()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundColor(.white)
                    .background(
                        isTitleValid
                            ? AnyShapeStyle(AppTheme.primaryGradient)
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .cornerRadius(16)
                }
                .disabled(!isTitleValid)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.background)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Step 2: Target Hours Slider

    var stepTwoView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(AppTheme.primaryGradient)
                            .padding(.top, 40)

                        Text("How many hours?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Set your target for \"\(title)\"")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    // Hours display
                    VStack(spacing: 8) {
                        Text("\(Int(targetHours))")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primaryGradient)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: targetHours)

                        Text("hours")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    // Slider
                    VStack(spacing: 16) {
                        Slider(value: $targetHours, in: 1...100, step: 1)
                            .tint(AppTheme.actionBlue)
                            .padding(.horizontal, 8)

                        // Quick select buttons
                        HStack(spacing: 12) {
                            ForEach([5, 10, 20, 50], id: \.self) { hours in
                                Button {
                                    withAnimation(.snappy) {
                                        targetHours = Double(hours)
                                    }
                                } label: {
                                    Text("\(hours)h")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Int(targetHours) == hours ? .white : AppTheme.actionBlue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Int(targetHours) == hours
                                                ? AnyShapeStyle(AppTheme.primaryGradient)
                                                : AnyShapeStyle(AppTheme.actionBlue.opacity(0.1))
                                        )
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 100)
            }

            Spacer()

            // Create button
            VStack(spacing: 0) {
                Divider()

                Button {
                    createGoal()
                } label: {
                    HStack(spacing: 10) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Create Goal")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundColor(.white)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.actionBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isCreating)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AppTheme.background)
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

// Custom TextField Style
struct PlayfulTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(AppTheme.textPrimary)
            .tint(AppTheme.actionBlue)
            .padding()
            .background(Color.white)
            .cornerRadius(AppTheme.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                    .stroke(AppTheme.borderLight, lineWidth: 1.5)
            )
    }
}

// Custom placeholder modifier for better contrast
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    CreateGoalView(viewModel: GoalsViewModel())
}
