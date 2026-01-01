//
//  StealthStopwatchView.swift
//  LockIn
//
//  Created by Claude on 01/01/26.
//

import SwiftUI

/// A minimal stopwatch display for stealth recording mode.
/// Shows only the recording duration on a black background - clean and unobtrusive.
struct StealthStopwatchView: View {
    let recordingDuration: TimeInterval
    let onDoubleTap: () -> Void
    let onStopRecording: () -> Void

    @State private var showStopButton = false

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    onDoubleTap()
                }

            VStack(spacing: 16) {
                Spacer()

                // Minimal recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulsingOpacity)

                    Text("REC")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Large stopwatch display
                Text(formattedDuration)
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Spacer()

                // Hint text
                Text("Double-tap to show controls")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 60)
            }

            // Stop button overlay (long-press to reveal)
            if showStopButton {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showStopButton = false }
                    }

                VStack(spacing: 20) {
                    Text("Long-press to access")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Button {
                        onStopRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop Recording")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showStopButton = true
            }
            // Auto-hide after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeIn(duration: 0.3)) {
                    showStopButton = false
                }
            }
        }
    }

    private var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    @State private var isPulsing = false

    private var pulsingOpacity: Double {
        isPulsing ? 0.3 : 1.0
    }

    init(recordingDuration: TimeInterval, onDoubleTap: @escaping () -> Void, onStopRecording: @escaping () -> Void) {
        self.recordingDuration = recordingDuration
        self.onDoubleTap = onDoubleTap
        self.onStopRecording = onStopRecording
    }
}

// MARK: - Pulsing Animation Wrapper

struct StealthStopwatchViewWrapper: View {
    let recordingDuration: TimeInterval
    let onDoubleTap: () -> Void
    let onStopRecording: () -> Void

    @State private var isPulsing = false

    var body: some View {
        StealthStopwatchViewInternal(
            recordingDuration: recordingDuration,
            onDoubleTap: onDoubleTap,
            onStopRecording: onStopRecording,
            isPulsing: isPulsing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct StealthStopwatchViewInternal: View {
    let recordingDuration: TimeInterval
    let onDoubleTap: () -> Void
    let onStopRecording: () -> Void
    let isPulsing: Bool

    @State private var showStopButton = false

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    onDoubleTap()
                }

            VStack(spacing: 16) {
                Spacer()

                // Minimal recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(isPulsing ? 0.3 : 1.0)

                    Text("REC")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Large stopwatch display
                Text(formattedDuration)
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Spacer()

                // Hint text
                Text("Double-tap to show controls")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 60)
            }

            // Stop button overlay (long-press to reveal)
            if showStopButton {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showStopButton = false }
                    }

                VStack(spacing: 20) {
                    Text("Long-press to access")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Button {
                        onStopRecording()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop Recording")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showStopButton = true
            }
            // Auto-hide after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeIn(duration: 0.3)) {
                    showStopButton = false
                }
            }
        }
    }

    private var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preview

#Preview {
    StealthStopwatchView(
        recordingDuration: 3725,
        onDoubleTap: { },
        onStopRecording: { }
    )
}
