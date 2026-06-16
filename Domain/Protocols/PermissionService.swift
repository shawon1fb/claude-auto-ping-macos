import Foundation

/// The state of a single macOS permission.
public enum PermissionStatus: Sendable, Equatable {
    case granted
    case denied
    case unknown

    public var isGranted: Bool { self == .granted }
}

/// Inspects and helps the user grant the permissions required for UI automation.
/// Implementations must never prompt repeatedly in a loop.
@MainActor
public protocol PermissionService: AnyObject {
    /// Current Accessibility (AXIsProcessTrusted) status.
    func accessibilityStatus() -> PermissionStatus
    /// Prompts once for Accessibility access if not yet determined.
    func requestAccessibilityPrompt()
    func openAccessibilitySettings()
    func openAutomationSettings()
}
