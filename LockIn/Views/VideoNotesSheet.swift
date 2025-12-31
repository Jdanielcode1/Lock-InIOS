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
    var isEditing: Bool = false  // True when editing existing notes

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)

                    Text(isEditing ? "Edit Notes" : "Add Notes")
                        .font(.title2.bold())

                    Text("Capture your thoughts, learnings, or what you accomplished")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Text Editor
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("What did you learn or accomplish?")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $notes)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .focused($isFocused)
                }
                .frame(minHeight: 150, maxHeight: 250)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                // Tip about dictation
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                    Text("Tip: Use the microphone on your keyboard to dictate")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Skip") {
                        onSkip()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Delay focus slightly for smoother sheet presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
        .interactiveDismissDisabled(!isEditing) // Prevent accidental dismiss when adding new notes
    }
}

#Preview {
    VideoNotesSheet(
        notes: .constant(""),
        onSave: {},
        onSkip: {}
    )
}
