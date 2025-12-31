//
//  VideoNotesSheet.swift
//  LockIn
//
//  Created by Claude on 30/12/25.
//

import SwiftUI

struct VideoNotesSheet: View {
    @Binding var notes: String
    var onSave: () -> Void
    var onSkip: () -> Void
    var isEditing: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar - just close button
                HStack {
                    Button {
                        handleDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // TextEditor - the hero
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("What did you accomplish?")
                            .font(.system(size: 18))
                            .foregroundColor(Color(.quaternaryLabel))
                            .padding(.top, 8)
                    }

                    TextEditor(text: $notes)
                        .font(.system(size: 18))
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()

                // Done button - bottom center
                Button {
                    onSave()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 44)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private func handleDismiss() {
        // If empty, just skip. If has content, save it.
        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSkip()
        } else {
            onSave()
        }
    }
}

#Preview {
    VideoNotesSheet(
        notes: .constant(""),
        onSave: {},
        onSkip: {}
    )
}
