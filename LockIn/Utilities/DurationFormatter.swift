//
//  DurationFormatter.swift
//  LockIn
//
//  Created by Claude on 29/12/25.
//

import Foundation

extension Double {
    /// Formats hours as a readable string, showing minutes if less than 1 hour
    /// Example: 0.5 -> "30 min", 2.5 -> "2.5h", 0 -> "0 min"
    var formattedDuration: String {
        if self < 1 {
            let minutes = Int(self * 60)
            return "\(minutes) min"
        } else {
            return String(format: "%.1fh", self)
        }
    }

    /// Formats hours as a compact string for badges/small spaces
    /// Example: 0.5 -> "30m", 2.5 -> "2.5h", 0 -> "0m"
    var formattedDurationCompact: String {
        if self < 1 {
            let minutes = Int(self * 60)
            return "\(minutes)m"
        } else {
            return String(format: "%.1fh", self)
        }
    }

    /// Formats a target/progress pair like "30 min of 10 hours" or "2h of 10h"
    func formattedProgress(of target: Double) -> String {
        let completedStr: String
        let targetStr: String

        // Format completed
        if self < 1 {
            let minutes = Int(self * 60)
            completedStr = "\(minutes) min"
        } else {
            completedStr = String(format: "%.1fh", self)
        }

        // Format target (always in hours if >= 1)
        if target < 1 {
            let minutes = Int(target * 60)
            targetStr = "\(minutes) min"
        } else {
            targetStr = "\(Int(target))h"
        }

        return "\(completedStr) of \(targetStr)"
    }

    /// Formats as "X/Y hrs" or "Xm/Yh" for compact progress display
    func formattedProgressCompact(of target: Double) -> String {
        let completedStr: String
        let targetStr: String

        // Format completed
        if self < 1 {
            let minutes = Int(self * 60)
            completedStr = "\(minutes)m"
        } else {
            completedStr = "\(Int(self))h"
        }

        // Format target
        if target < 1 {
            let minutes = Int(target * 60)
            targetStr = "\(minutes)m"
        } else {
            targetStr = "\(Int(target))h"
        }

        return "\(completedStr)/\(targetStr)"
    }
}
