import Foundation
import AppKit
import ApplicationServices
import OSLog

/// `PermissionService` backed by the Accessibility trust APIs. It checks status
/// without prompting, prompts at most once on explicit request, and deep-links
/// into the relevant System Settings panes.
@MainActor
public final class AccessibilityPermissionService: PermissionService {
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "Permissions")

    public init() {}

    public func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    public func requestAccessibilityPrompt() {
        guard !AXIsProcessTrusted() else { return }
        // The key constant `kAXTrustedCheckOptionPrompt` is an imported global
        // that is not concurrency-safe; its value is this stable string.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        // Passing the prompt option shows the system dialog exactly once per
        // call; callers invoke this only in response to a user action.
        _ = AXIsProcessTrustedWithOptions(options)
        logger.info("Requested Accessibility prompt")
    }

    public func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
