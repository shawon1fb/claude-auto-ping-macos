import Foundation

/// All user-configurable, persisted settings for the scheduler and automation.
///
/// This is plain value data with no system or UI dependencies so it can be
/// encoded, decoded, and unit-tested in isolation. The `version` field supports
/// forward migration of stored data. Decoding is tolerant: any missing key
/// falls back to its default, so adding fields never invalidates stored data.
public struct SchedulerConfiguration: Codable, Sendable, Equatable {
    /// The minimum interval the app will ever schedule, in seconds (5 minutes).
    public static let minimumIntervalSeconds: TimeInterval = 5 * 60

    /// Intervals shorter than this prompt a warning in the UI.
    public static let shortIntervalWarningThreshold: TimeInterval = 30 * 60

    public static let currentVersion = 2

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

    // MARK: Reset window
    /// When enabled, the schedule is anchored to a user-provided Claude usage
    /// reset time so each message lands at a window reset and every interval
    /// after, rather than `now + interval`. This is the default behavior.
    public var anchorToResetTime: Bool
    /// The reference reset instant. Only its time-of-day matters; the scheduler
    /// rolls it forward by the interval to the next future slot. `nil` means the
    /// user has not set a reset time yet, in which case the schedule falls back
    /// to `now + interval`.
    public var resetAnchorDate: Date?

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
        anchorToResetTime: Bool = true,
        resetAnchorDate: Date? = nil,
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
        self.anchorToResetTime = anchorToResetTime
        self.resetAnchorDate = resetAnchorDate
        self.claudeAppPath = claudeAppPath
        self.newChatShortcut = newChatShortcut
        self.launchDelay = launchDelay
        self.newChatDelay = newChatDelay
        self.sendDelay = sendDelay
        self.pressReturnAutomatically = pressReturnAutomatically
        self.duplicateCooldown = duplicateCooldown
        self.logRetentionCount = logRetentionCount
    }

    /// Tolerant decoding: every key is optional and falls back to its default,
    /// so older or partial stored payloads decode cleanly instead of throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SchedulerConfiguration()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        version = try value(.version, defaults.version)
        message = try value(.message, defaults.message)
        intervalPreset = try value(.intervalPreset, defaults.intervalPreset)
        customIntervalSeconds = try value(.customIntervalSeconds, defaults.customIntervalSeconds)
        isEnabled = try value(.isEnabled, defaults.isEnabled)
        startAutomatically = try value(.startAutomatically, defaults.startAutomatically)
        launchAtLogin = try value(.launchAtLogin, defaults.launchAtLogin)
        wakeRecoveryEnabled = try value(.wakeRecoveryEnabled, defaults.wakeRecoveryEnabled)
        notifyOnSuccess = try value(.notifyOnSuccess, defaults.notifyOnSuccess)
        notifyOnFailure = try value(.notifyOnFailure, defaults.notifyOnFailure)
        anchorToResetTime = try value(.anchorToResetTime, defaults.anchorToResetTime)
        resetAnchorDate = try container.decodeIfPresent(Date.self, forKey: .resetAnchorDate)
        claudeAppPath = try container.decodeIfPresent(String.self, forKey: .claudeAppPath)
        newChatShortcut = try value(.newChatShortcut, defaults.newChatShortcut)
        launchDelay = try value(.launchDelay, defaults.launchDelay)
        newChatDelay = try value(.newChatDelay, defaults.newChatDelay)
        sendDelay = try value(.sendDelay, defaults.sendDelay)
        pressReturnAutomatically = try value(.pressReturnAutomatically, defaults.pressReturnAutomatically)
        duplicateCooldown = try value(.duplicateCooldown, defaults.duplicateCooldown)
        logRetentionCount = try value(.logRetentionCount, defaults.logRetentionCount)
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
