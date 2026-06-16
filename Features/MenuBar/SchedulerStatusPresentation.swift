import SwiftUI

/// UI presentation derived from `SchedulerStatus`: the SF Symbol, a tint color,
/// and accessible text. Kept out of the domain enum so the model stays free of
/// SwiftUI.
extension SchedulerStatus {
    var menuBarSymbolName: String {
        switch self {
        case .running: return "paperplane.circle.fill"
        case .paused: return "pause.circle"
        case .stopped: return "moon.zzz"
        case .error: return "exclamationmark.triangle"
        case .permissionRequired: return "lock.trianglebadge.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .running: return .accentColor
        case .paused: return .secondary
        case .stopped: return .secondary
        case .error: return .red
        case .permissionRequired: return .orange
        }
    }

    var title: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .error: return "Error"
        case .permissionRequired: return "Permission required"
        }
    }

    /// A longer description, including any embedded error message.
    var detailText: String {
        switch self {
        case .running: return "The scheduler is running."
        case .paused: return "The scheduler is paused."
        case .stopped: return "The scheduler is stopped."
        case .error(let message): return message
        case .permissionRequired: return "Accessibility permission is required to send messages."
        }
    }

    var accessibilityDescription: String {
        "Claude Auto Ping status: \(title)"
    }
}
