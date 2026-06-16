import Foundation
import OSLog

/// The production `AutomationService`. It readies Claude via an injected
/// `ClaudeAppController`, opens a new chat with a configurable shortcut, pastes
/// the message via the clipboard (never via interpolated script source),
/// optionally presses Return, and always restores the previous clipboard — even
/// on failure.
public final class ClaudeAutomationService: AutomationService {
    private let controller: ClaudeAppController
    private let scriptRunner: AppleScriptRunner
    private let clipboard: ClipboardManager
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "Automation")

    public init(
        controller: ClaudeAppController,
        scriptRunner: AppleScriptRunner,
        clipboard: ClipboardManager
    ) {
        self.controller = controller
        self.scriptRunner = scriptRunner
        self.clipboard = clipboard
    }

    public func sendMessage(
        _ message: String,
        configuration: AutomationConfiguration
    ) async throws -> AutomationResult {
        let start = Date()
        var result = AutomationResult()

        // 1–4. Launch (if needed), activate, and wait for readiness.
        result.didLaunchClaude = try await controller.prepare(
            preferredPath: configuration.claudeAppPath,
            launchDelay: configuration.launchDelay
        )
        result.didActivate = true

        // The clipboard snapshot must be restored no matter what happens next.
        let snapshot = clipboard.snapshot()
        defer { clipboard.restore(snapshot) }

        do {
            // 5. Open a new conversation.
            try sendShortcut(configuration.newChatShortcut)
            result.didOpenNewChat = true
            try await sleep(configuration.newChatDelay)

            // 6. Place the message on the clipboard and paste it.
            try clipboard.setString(message)
            try paste()
            result.didPaste = true
            try await sleep(configuration.sendDelay)

            // 7. Optionally press Return to send.
            if configuration.pressReturn {
                try pressReturn()
                result.didSend = true
            }
        } catch {
            result.duration = Date().timeIntervalSince(start)
            logger.error("Automation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        result.duration = Date().timeIntervalSince(start)
        return result
    }

    // MARK: - Steps

    private func sendShortcut(_ shortcut: KeyboardShortcut) throws {
        let modifiers = shortcut.appleScriptModifiers.joined(separator: ", ")
        let usingClause = modifiers.isEmpty ? "" : " using {\(modifiers)}"
        // The key character is the app's own configured shortcut, not user text.
        let escapedKey = shortcut.key.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "System Events"
            keystroke "\(escapedKey)"\(usingClause)
        end tell
        """
        try runStep(source, mapTo: .newChatShortcutFailed)
    }

    private func paste() throws {
        let source = """
        tell application "System Events"
            keystroke "v" using {command down}
        end tell
        """
        try runStep(source, mapTo: .pasteFailed)
    }

    private func pressReturn() throws {
        let source = """
        tell application "System Events"
            key code 36
        end tell
        """
        try runStep(source, mapTo: .sendFailed)
    }

    /// Runs a script step, preserving an explicit permission error but otherwise
    /// mapping failures to the supplied step-specific error.
    private func runStep(_ source: String, mapTo stepError: AutomationError) throws {
        do {
            try scriptRunner.run(source)
        } catch let error as AutomationError {
            if case .automationPermissionDenied = error { throw error }
            throw stepError
        }
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
