import Foundation
import UserNotifications
import OSLog

/// `NotificationService` over `UNUserNotificationCenter`. Authorization is
/// requested once; delivery is best-effort and never blocks automation.
public final class UserNotificationService: NotificationService {
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "Notifications")

    public init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            if let error {
                logger.error("Notification authorization error: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Notification authorization granted=\(granted, privacy: .public)")
            }
        }
    }

    public func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
