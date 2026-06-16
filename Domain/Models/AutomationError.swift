import Foundation

/// User-facing, typed automation errors. Each case carries a clear description
/// and a suggested recovery action; raw technical detail belongs in the logs,
/// not the UI.
public enum AutomationError: Error, Sendable, Equatable {
    case claudeNotInstalled
    case claudeLaunchFailed
    case accessibilityPermissionDenied
    case automationPermissionDenied
    case claudeProcessNotFound
    case newChatShortcutFailed
    case clipboardWriteFailed
    case pasteFailed
    case sendFailed
    case invalidConfiguration(String)
    case duplicateExecutionBlocked
    case timedOut
    case screenLocked
    case scriptFailed(String)
}

extension AutomationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            return "The Claude desktop app could not be found."
        case .claudeLaunchFailed:
            return "Claude could not be launched."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is not granted."
        case .automationPermissionDenied:
            return "Automation permission is not granted."
        case .claudeProcessNotFound:
            return "Claude is not running and could not be started."
        case .newChatShortcutFailed:
            return "The new-chat keyboard shortcut did not work."
        case .clipboardWriteFailed:
            return "The message could not be placed on the clipboard."
        case .pasteFailed:
            return "The message could not be pasted into Claude."
        case .sendFailed:
            return "The message could not be sent."
        case .invalidConfiguration(let reason):
            return "The scheduler configuration is invalid: \(reason)"
        case .duplicateExecutionBlocked:
            return "A duplicate send was blocked by the cooldown window."
        case .timedOut:
            return "The automation timed out waiting for Claude."
        case .screenLocked:
            return "The Mac is locked, so automation was skipped."
        case .scriptFailed(let detail):
            return "The automation script failed: \(detail)"
        }
    }

    /// A concrete next step the user can take to recover.
    public var recoverySuggestion: String? {
        switch self {
        case .claudeNotInstalled:
            return "Install Claude, or choose its location in Automation settings."
        case .claudeLaunchFailed:
            return "Open Claude manually once, then run the test again."
        case .accessibilityPermissionDenied:
            return "Open Accessibility settings and enable Claude Auto Ping."
        case .automationPermissionDenied:
            return "Open Automation settings and allow control of System Events."
        case .claudeProcessNotFound:
            return "Verify the selected Claude app path in Automation settings."
        case .newChatShortcutFailed:
            return "Check the new-chat shortcut in Automation settings."
        case .clipboardWriteFailed:
            return "Try again; another app may be holding the clipboard."
        case .pasteFailed:
            return "Make sure Claude is frontmost, then run a dry-run test."
        case .sendFailed:
            return "Increase the send delay in Automation settings."
        case .invalidConfiguration:
            return "Review the interval and message in General settings."
        case .duplicateExecutionBlocked:
            return "This is expected protection; no action needed."
        case .timedOut:
            return "Increase the launch and new-chat delays, then retry."
        case .screenLocked:
            return "Unlock the Mac; the next scheduled run will proceed."
        case .scriptFailed:
            return "Check Accessibility and Automation permissions, then retry."
        }
    }
}
