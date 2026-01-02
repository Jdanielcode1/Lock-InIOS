//
//  FABPopupMenu.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct FABPopupMenu: View {
    @Binding var isPresented: Bool
    var onNewGoal: () -> Void
    var onNewTodo: () -> Void

    @State private var showItems = false

    var body: some View {
        ZStack {
            // Dimmed background
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissMenu()
                    }
                    .transition(.opacity)
            }

            // Menu items
            if isPresented {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 12) {
                        // New Goal option
                        FABMenuItem(
                            icon: "target",
                            title: "New Goal",
                            subtitle: "Track study hours",
                            color: .accentColor
                        ) {
                            dismissMenu()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onNewGoal()
                            }
                        }
                        .offset(y: showItems ? 0 : 20)
                        .opacity(showItems ? 1 : 0)

                        // New To-Do option
                        FABMenuItem(
                            icon: "checklist",
                            title: "New To-Do",
                            subtitle: "Quick task with video",
                            color: .green
                        ) {
                            dismissMenu()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onNewTodo()
                            }
                        }
                        .offset(y: showItems ? 0 : 30)
                        .opacity(showItems ? 1 : 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for tab bar + FAB
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05), value: showItems)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.1)) {
                    showItems = true
                }
            } else {
                showItems = false
            }
        }
    }

    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showItems = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isPresented = false
            }
        }
    }
}

struct FABMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(FABMenuButtonStyle())
    }
}

struct FABMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()

        FABPopupMenu(isPresented: .constant(true)) {
            print("New Goal")
        } onNewTodo: {
            print("New Todo")
        }
    }
}
