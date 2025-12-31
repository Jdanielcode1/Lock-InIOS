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
    @State private var showWordCount = true
    @State private var typingTimer: Timer?

    private var wordCount: Int {
        let words = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

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
                        .onChange(of: notes) { oldValue, newValue in
                            handleTextChange(oldValue: oldValue, newValue: newValue)
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()

                // Bottom bar - word count + done button
                HStack {
                    // Word count (fades while typing)
                    if wordCount > 0 {
                        Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.quaternaryLabel))
                            .opacity(showWordCount ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: showWordCount)
                    }

                    Spacer()

                    // Done button
                    Button {
                        onSave()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 40)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        // Auto-bullet: Replace "- " at start of line with "• "
        var updated = newValue

        // Replace "- " at the very start of text
        if updated.hasPrefix("- ") {
            updated = "• " + updated.dropFirst(2)
        }

        // Replace "- " after any newline
        updated = updated.replacingOccurrences(of: "\n- ", with: "\n• ")

        // Only update if something changed (prevents infinite loop)
        if updated != newValue {
            notes = updated
            return
        }

        // Fade word count while typing
        showWordCount = false
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation {
                showWordCount = true
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
