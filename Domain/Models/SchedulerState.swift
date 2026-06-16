import Foundation

/// The high-level status of the scheduler, surfaced to the menu bar UI.
public enum SchedulerStatus: Sendable, Equatable {
    case stopped
    case running
    case paused
    case error(String)
    case permissionRequired

    public var isActive: Bool {
        if case .running = self { return true }
        return false
    }
}

/// What caused an automation run, used for logging and diagnostics.
public enum TriggerSource: String, Codable, Sendable {
    case scheduledTimer
    case manualTest
    case wakeRecovery
    case dryRun

    public var displayName: String {
        switch self {
        case .scheduledTimer: return "Scheduled"
        case .manualTest: return "Manual test"
        case .wakeRecovery: return "Wake recovery"
        case .dryRun: return "Dry run"
        }
    }
}
