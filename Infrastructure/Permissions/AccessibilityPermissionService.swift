import Foundation
import AppKit
import ApplicationServices
import Carbon
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

    public func automationStatus() -> PermissionStatus {
        // Probe permission to send Apple Events to System Events without
        // prompting. macOS records a decision only after the first real attempt,
        // so an undetermined result maps to `.unknown`.
        let bundleID = "com.apple.systemevents"

        // AEDeterminePermissionToAutomateTarget requires the target to be
        // running; otherwise it returns procNotFound and logs noise on every
        // call. System Events is a faceless app that quits when idle, so guard
        // on it being running and treat "not running" as undetermined.
        let isSystemEventsRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).isEmpty
        guard isSystemEventsRunning else { return .unknown }

        var target = AEAddressDesc()
        let createStatus = Data(bundleID.utf8).withUnsafeBytes { buffer in
            AECreateDesc(typeApplicationBundleID, buffer.baseAddress, buffer.count, &target)
        }
        guard createStatus == noErr else { return .unknown }
        defer { AEDisposeDesc(&target) }

        let result = AEDeterminePermissionToAutomateTarget(
            &target,
            AEEventClass(kCoreEventClass),
            AEEventID(kAEOpenApplication),
            false
        )
        switch result {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        default:
            // errAEEventWouldRequireUserConsent (-1744) or procNotFound: not yet
            // decided, so we cannot claim it is granted or denied.
            return .unknown
        }
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
