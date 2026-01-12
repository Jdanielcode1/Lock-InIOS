//
//  ToastView.swift
//  LockIn
//
//  Created by Claude on 01/07/26.
//

import SwiftUI

/// A floating toast notification for deletion confirmations with undo support
struct ToastView: View {
    @ObservedObject var toastManager = ToastManager.shared

    var body: some View {
        if let toast = toastManager.currentToast, toastManager.isVisible {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))

                // Message
                Text(toast.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Spacer()

                // Undo button (if action available)
                if toast.undoAction != nil {
                    Button {
                        toastManager.undo()
                    } label: {
                        Text("Undo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.darkGray))
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 20 {
                            toastManager.dismiss()
                        }
                    }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// View modifier to add toast support to any view
struct ToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ToastView()
                    .padding(.bottom, 100) // Above tab bar
            }
    }
}

extension View {
    /// Adds toast notification support to this view
    func withToasts() -> some View {
        modifier(ToastModifier())
    }
}

#Preview {
    VStack {
        Spacer()
        Text("Main Content")
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .overlay(alignment: .bottom) {
        ToastView()
            .padding(.bottom, 100)
            .onAppear {
                ToastManager.shared.showDeleted("Goal", undoAction: {
                    print("Undo tapped")
                })
            }
    }
}
