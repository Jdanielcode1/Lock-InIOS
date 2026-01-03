//
//  CircularProgressRing.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import SwiftUI

struct CircularProgressRing: View {
    let progress: Double // 0-100
    let completedHours: Double
    let targetHours: Double
    var isCompleted: Bool = false
    var size: CGFloat = 140
    var lineWidth: CGFloat = 12

    @State private var animatedProgress: Double = 0

    private var progressColor: Color {
        if isCompleted {
            return .green
        } else if progress >= 75 {
            return .orange
        } else {
            return .accentColor
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color(UIColor.systemGray5),
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress / 100)
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animatedProgress)

            // Center content
            VStack(spacing: 4) {
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text(completedHours.formattedDurationCompact)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                Text("of \(targetHours.formattedDurationCompact)")
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = min(progress, 100)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = min(newValue, 100)
            }
        }
    }
}

// Compact version for list rows
struct CompactProgressRing: View {
    let progress: Double
    var isCompleted: Bool = false
    var size: CGFloat = 44
    var lineWidth: CGFloat = 4

    private var progressColor: Color {
        if isCompleted {
            return .green
        } else {
            return .accentColor
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(UIColor.systemGray5), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(progress))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 40) {
        CircularProgressRing(
            progress: 45,
            completedHours: 4.5,
            targetHours: 10
        )

        CircularProgressRing(
            progress: 100,
            completedHours: 10,
            targetHours: 10,
            isCompleted: true
        )

        HStack(spacing: 20) {
            CompactProgressRing(progress: 25)
            CompactProgressRing(progress: 75)
            CompactProgressRing(progress: 100, isCompleted: true)
        }
    }
    .padding()
}
