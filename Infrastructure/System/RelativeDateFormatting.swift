import Foundation

/// Shared, locale-aware date formatting for the UI. Centralized so the menu bar
/// and logs render times consistently.
public enum DateDisplay {
    private static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    public static func dateTimeString(_ date: Date) -> String {
        dateTime.string(from: date)
    }

    public static func timeString(_ date: Date) -> String {
        timeOnly.string(from: date)
    }

    /// A compact human description of an interval in seconds, for example
    /// "Every 5 hours" or "Every 90 minutes".
    public static func intervalDescription(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        if totalMinutes % 60 == 0 {
            let hours = totalMinutes / 60
            return hours == 1 ? "Every hour" : "Every \(hours) hours"
        }
        if totalMinutes < 60 {
            return "Every \(totalMinutes) minutes"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "Every \(hours)h \(minutes)m"
    }
}
