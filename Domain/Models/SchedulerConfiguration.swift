import Foundation

/// All user-configurable, persisted settings for the scheduler and automation.
///
/// This is plain value data with no system or UI dependencies so it can be
/// encoded, decoded, and unit-tested in isolation. The `version` field supports
/// forward migration of stored data.
public struct SchedulerConfiguration: Codable, Sendable, Equatable {
    /// The minimum interval the app will ever schedule, in seconds (5 minutes).
    public static let minimumIntervalSeconds: TimeInterval = 5 * 60

    /// Intervals shorter than this prompt a warning in the UI.
    public static let shortIntervalWarningThreshold: TimeInterval = 30 * 60

    public static let currentVersion = 1

    public var version: Int

    // MARK: General
    public var message: String
    public var intervalPreset: IntervalPreset
    public var customIntervalSeconds: TimeInterval
    public var isEnabled: Bool
    public var startAutomatically: Bool
    public var launchAtLogin: Bool
    public var wakeRecoveryEnabled: Bool
    public var notifyOnSuccess: Bool
    public var notifyOnFailure: Bool

    // MARK: Automation
    public var claudeAppPath: String?
    public var newChatShortcut: KeyboardShortcut
    public var launchDelay: TimeInterval
    public var newChatDelay: TimeInterval
    public var sendDelay: TimeInterval
    public var pressReturnAutomatically: Bool

    // MARK: Advanced
    public var duplicateCooldown: TimeInterval
    public var logRetentionCount: Int

    public init(
        version: Int = SchedulerConfiguration.currentVersion,
        message: String = "hi",
        intervalPreset: IntervalPreset = .fiveHours,
        customIntervalSeconds: TimeInterval = 5 * 60 * 60,
        isEnabled: Bool = false,
        startAutomatically: Bool = false,
        launchAtLogin: Bool = false,
        wakeRecoveryEnabled: Bool = true,
        notifyOnSuccess: Bool = false,
        notifyOnFailure: Bool = true,
        claudeAppPath: String? = nil,
        newChatShortcut: KeyboardShortcut = .newChat,
        launchDelay: TimeInterval = 3.0,
        newChatDelay: TimeInterval = 1.5,
        sendDelay: TimeInterval = 0.8,
        pressReturnAutomatically: Bool = true,
        duplicateCooldown: TimeInterval = 5 * 60,
        logRetentionCount: Int = 100
    ) {
        self.version = version
        self.message = message
        self.intervalPreset = intervalPreset
        self.customIntervalSeconds = customIntervalSeconds
        self.isEnabled = isEnabled
        self.startAutomatically = startAutomatically
        self.launchAtLogin = launchAtLogin
        self.wakeRecoveryEnabled = wakeRecoveryEnabled
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
        self.claudeAppPath = claudeAppPath
        self.newChatShortcut = newChatShortcut
        self.launchDelay = launchDelay
        self.newChatDelay = newChatDelay
        self.sendDelay = sendDelay
        self.pressReturnAutomatically = pressReturnAutomatically
        self.duplicateCooldown = duplicateCooldown
        self.logRetentionCount = logRetentionCount
    }

    /// The effective interval in seconds, always clamped to the minimum.
    public var effectiveIntervalSeconds: TimeInterval {
        let raw = intervalPreset.seconds ?? customIntervalSeconds
        return max(raw, Self.minimumIntervalSeconds)
    }

    /// Whether the effective interval is short enough to warrant a UI warning.
    public var isShortInterval: Bool {
        effectiveIntervalSeconds < Self.shortIntervalWarningThreshold
    }

    public var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
