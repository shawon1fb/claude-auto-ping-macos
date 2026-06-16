import Foundation

/// Manages whether the app launches automatically at login, typically backed by
/// `SMAppService`.
public protocol LaunchAtLoginService: Sendable {
    /// Whether launch-at-login is currently registered and enabled.
    var isEnabled: Bool { get }
    /// Registers or unregisters the login item. Throws on failure so the UI can
    /// surface the problem instead of silently diverging from the setting.
    func setEnabled(_ enabled: Bool) throws
}
