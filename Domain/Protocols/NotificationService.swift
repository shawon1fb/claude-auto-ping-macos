import Foundation

/// Posts native user notifications. All notifications are optional and gated by
/// user settings; the service itself simply delivers what it is asked to.
public protocol NotificationService: Sendable {
    /// Requests notification authorization once, early in the app lifecycle.
    func requestAuthorization()
    func notify(title: String, body: String)
}
