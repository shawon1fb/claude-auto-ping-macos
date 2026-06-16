import Foundation

/// User-selectable repeat intervals. `custom` defers to a configurable number
/// of seconds stored alongside the preset.
public enum IntervalPreset: String, Codable, CaseIterable, Sendable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fiveHours
    case eightHours
    case twelveHours
    case twentyFourHours
    case custom

    public var id: String { rawValue }

    /// The fixed duration in seconds, or `nil` for `custom`.
    public var seconds: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fiveHours: return 5 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .twentyFourHours: return 24 * 60 * 60
        case .custom: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .twoHours: return "Every 2 hours"
        case .fiveHours: return "Every 5 hours"
        case .eightHours: return "Every 8 hours"
        case .twelveHours: return "Every 12 hours"
        case .twentyFourHours: return "Every 24 hours"
        case .custom: return "Custom"
        }
    }
}
