//
//  DateFormatterCache.swift
//  LockIn
//
//  Created by Claude on 01/01/26.
//

import Foundation

/// Cached DateFormatters to avoid expensive initialization on every use.
/// DateFormatter creation is expensive - reusing static instances improves performance.
enum DateFormatterCache {

    // MARK: - Date Formatters

    /// Format: "Monday, Jan 1" - for timeline date headers
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    /// Format: "3:45 PM" - for time display
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Format: "Jan 1, 2026" - for short dates
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Format: "1/1/26" - for compact dates
    static let compactDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Calendar

    /// Cached calendar instance to avoid repeated Calendar.current lookups
    static let calendar: Calendar = Calendar.current

    // MARK: - Convenience Methods

    /// Format date for timeline headers with Today/Yesterday support
    static func formatDateHeader(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return fullDate.string(from: date)
        }
    }

    /// Format time as "3:45 PM"
    static func formatTime(_ date: Date) -> String {
        time.string(from: date)
    }

    /// Get start of day for a date
    static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
