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
    @ObservationIgnored private let scriptRunner: AppleScriptRunner
    @ObservationIgnored private let wakeObserver = WakeObserver()
    @ObservationIgnored private var activationObserver: NSObjectProtocol?
    @ObservationIgnored private let logger = Logger(subsystem: AppInfo.subsystem, category: "AppEnvironment")

    /// Detected Claude app URL, refreshed by `detectClaude()`.
    public private(set) var detectedClaudeURL: URL?
    /// The most recent error surfaced from a user action, for display.
    public private(set) var lastActionError: String?

    public init() {
        let settingsStore = UserDefaultsSettingsStore()
        let locator = DefaultClaudeAppLocator()
        let scriptRunner = NSAppleScriptRunner()
        let automation = ClaudeAutomationService(
            controller: DefaultClaudeAppController(locator: locator),
            scriptRunner: scriptRunner,
            clipboard: DefaultClipboardManager()
        )
        let logStore = FileLogStore()
        let permission = AccessibilityPermissionService()
        let notifications = UserNotificationService()

        self.locator = locator
        self.logStore = logStore
        self.permission = permission
        self.notifications = notifications
        self.scriptRunner = scriptRunner
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

        // Re-check permissions whenever the app becomes active, so a grant made
        // in System Settings is reflected immediately (no relaunch needed).
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermissions()
            }
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

    /// Asks for Accessibility access. Returns a short, user-facing result so the
    /// UI can give feedback. The system prompt only appears the first time macOS
    /// encounters the app; once it is already listed, the prompt is suppressed,
    /// so we always open the Accessibility pane as a reliable fallback.
    @discardableResult
    public func requestAccessibility() -> String {
        if accessibilityGranted {
            return "Accessibility is already granted."
        }
        permission.requestAccessibilityPrompt()
        permission.openAccessibilitySettings()
        return "Opened Accessibility settings. Enable Claude Auto Ping, then return here."
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

    public var automationStatus: PermissionStatus {
        permission.automationStatus()
    }

    /// Sends a harmless Apple event directly to System Events to trigger the
    /// one-time Automation consent dialog and register the app in the Automation
    /// list. Unlike a full dry-run, this does not depend on Claude being present
    /// or Accessibility being granted, so it reliably surfaces the prompt. The
    /// script actually launches System Events and sends an event, so its result
    /// is the authoritative Automation status. Runs off the main actor because
    /// the script call blocks while the dialog shows.
    public func requestAutomationPrompt() async -> PermissionStatus {
        let runner = scriptRunner
        return await Task.detached {
            do {
                _ = try runner.run("tell application \"System Events\" to return name")
                return .granted
            } catch let error as AutomationError {
                if case .automationPermissionDenied = error {
                    return .denied
                }
                return .unknown
            } catch {
                return .unknown
            }
        }.value
    }

    /// Re-checks permissions and Claude discovery, updating the scheduler's
    /// status. Triggered on app activation and by the Permissions UI.
    public func refreshPermissions() {
        scheduler.refreshPermissionState()
        detectClaude()
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
