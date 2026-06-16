import Foundation

/// Drives the Claude desktop app to send a single message. The whole UI
/// automation strategy lives behind this protocol so it can be mocked in tests
/// and swapped without touching the scheduler.
public protocol AutomationService: Sendable {
    /// Sends `message` using `configuration`. Throws an `AutomationError` on
    /// failure and is responsible for restoring any clipboard state it touched.
    func sendMessage(
        _ message: String,
        configuration: AutomationConfiguration
    ) async throws -> AutomationResult
}

/// Launches, foregrounds, and waits for the Claude app to be ready. Abstracted
/// from the automation service so the keystroke/clipboard logic can be unit
/// tested without a real Claude window or `NSWorkspace`.
public protocol ClaudeAppController: Sendable {
    /// Ensures Claude is running, frontmost, and ready to receive keystrokes,
    /// launching it if necessary. Returns whether it was launched by this call.
    /// Throws an `AutomationError` when the app cannot be found or readied.
    func prepare(preferredPath: String?, launchDelay: TimeInterval) async throws -> Bool
}

/// Locates the Claude desktop application across common install locations.
public protocol ClaudeAppLocator: Sendable {
    /// Returns the best Claude app URL, preferring `preferredPath` when valid.
    func locate(preferredPath: String?) -> URL?
    /// Whether an app at `url` is currently running.
    func isRunning(at url: URL) -> Bool
}

/// Executes AppleScript source and returns its textual output.
public protocol AppleScriptRunner: Sendable {
    @discardableResult
    func run(_ source: String) throws -> String?
}

/// A snapshot of the clipboard so it can be restored after pasting.
public struct ClipboardSnapshot: Sendable, Equatable {
    /// Per-type raw data captured from the general pasteboard.
    public var items: [String: Data]
    public init(items: [String: Data] = [:]) {
        self.items = items
    }
}

/// Safe, restore-aware access to the system clipboard.
public protocol ClipboardManager: Sendable {
    func snapshot() -> ClipboardSnapshot
    /// Replaces the clipboard contents with a plain string. Throws on failure.
    func setString(_ string: String) throws
    func restore(_ snapshot: ClipboardSnapshot)
}

/// Reports volatile system conditions that affect whether automation is safe.
public protocol SystemStateProvider: Sendable {
    /// Whether the screen is currently locked. When locked, automation is
    /// skipped rather than retried in a tight loop.
    func isScreenLocked() -> Bool
}
