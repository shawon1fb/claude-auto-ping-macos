import Foundation
import ServiceManagement
import OSLog

/// `LaunchAtLoginService` backed by `SMAppService.mainApp`. Registering the main
/// app as a login item requires no helper bundle on macOS 13+.
public struct DefaultLaunchAtLoginService: LaunchAtLoginService {
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "LaunchAtLogin")

    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            logger.error("Failed to set launch-at-login=\(enabled, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
