import Foundation
import AppKit
import Observation
import OSLog

/// The composition root and main-actor facade for the app. It wires concrete
/// services together (dependency injection happens here and only here) and
/// exposes high-level actions to the SwiftUI views, keeping business logic out
/// of the views themselves.
@MainActor
@Observable
public final class AppEnvironment {
    public let scheduler: DefaultSchedulerService
    public let logStore: LogStore

    @ObservationIgnored public let permission: PermissionService
    @ObservationIgnored private let launchAtLogin: LaunchAtLoginService
    @ObservationIgnored private let locator: ClaudeAppLocator
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let wakeObserver = WakeObserver()
    @ObservationIgnored private let logger = Logger(subsystem: AppInfo.subsystem, category: "AppEnvironment")

    /// Detected Claude app URL, refreshed by `detectClaude()`.
    public private(set) var detectedClaudeURL: URL?
    /// The most recent error surfaced from a user action, for display.
    public private(set) var lastActionError: String?

    public init() {
        let settingsStore = UserDefaultsSettingsStore()
        let locator = DefaultClaudeAppLocator()
        let automation = ClaudeAutomationService(
            controller: DefaultClaudeAppController(locator: locator),
            scriptRunner: NSAppleScriptRunner(),
            clipboard: DefaultClipboardManager()
        )
        let logStore = FileLogStore()
        let permission = AccessibilityPermissionService()
        let notifications = UserNotificationService()

        self.locator = locator
        self.logStore = logStore
        self.permission = permission
        self.notifications = notifications
        self.launchAtLogin = DefaultLaunchAtLoginService()
        self.scheduler = DefaultSchedulerService(
            settingsStore: settingsStore,
            automation: automation,
            logStore: logStore,
            clock: SystemClock(),
            permission: permission,
            notifications: notifications,
            systemState: DefaultSystemStateProvider(),
            ticker: TimerSchedulerTicker()
        )
    }

    /// Called once at launch to request authorization, observe wake events,
    /// resume an enabled scheduler, and honor the auto-start preference.
    public func bootstrap() {
        notifications.requestAuthorization()
        detectClaude()

        wakeObserver.start { [weak self] in
            guard let self else { return }
            Task { await self.scheduler.handleWake() }
        }

        if scheduler.configuration.startAutomatically, !scheduler.configuration.isEnabled {
            scheduler.start()
        } else {
            scheduler.activate()
        }
    }

    // MARK: - Configuration

    public func updateConfiguration(_ configuration: SchedulerConfiguration) {
        scheduler.updateConfiguration(configuration)
    }

    // MARK: - Claude discovery

    /// Locates Claude given an optional preferred path, without mutating state.
    public func locateClaude(preferredPath: String?) -> URL? {
        locator.locate(preferredPath: preferredPath)
    }

    @discardableResult
    public func detectClaude() -> URL? {
        let url = locator.locate(preferredPath: scheduler.configuration.claudeAppPath)
        detectedClaudeURL = url
        return url
    }

    /// Presents an open panel for the user to choose Claude manually, returning
    /// the chosen URL so the caller can update its configuration binding.
    public func presentClaudeChooser() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        detectedClaudeURL = url
        return url
    }

    // MARK: - Launch at login

    public var isLaunchAtLoginEnabled: Bool {
        launchAtLogin.isEnabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            var config = scheduler.configuration
            config.launchAtLogin = enabled
            scheduler.updateConfiguration(config)
            lastActionError = nil
        } catch {
            lastActionError = "Could not update launch at login: \(error.localizedDescription)"
            logger.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Permissions

    public func requestAccessibility() {
        permission.requestAccessibilityPrompt()
    }

    public func openAccessibilitySettings() {
        permission.openAccessibilitySettings()
    }

    public func openAutomationSettings() {
        permission.openAutomationSettings()
    }

    public var accessibilityGranted: Bool {
        permission.accessibilityStatus() == .granted
    }

    // MARK: - Logs maintenance

    public func openLogsDirectory() {
        let url = logStore.directoryURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    public func resetConfiguration() {
        scheduler.stop()
        UserDefaultsSettingsStore().reset()
        scheduler.updateConfiguration(SchedulerConfiguration())
    }

    /// Stops the scheduler and unregisters the login item, removing the app's
    /// background footprint. The standalone LaunchAgent (if used) is removed by
    /// its own uninstall script.
    public func uninstallBackgroundComponents() {
        scheduler.stop()
        try? launchAtLogin.setEnabled(false)
        var config = scheduler.configuration
        config.launchAtLogin = false
        config.startAutomatically = false
        scheduler.updateConfiguration(config)
    }
}
