import Foundation

/// Configuration handed to an `AutomationService` for a single run. Derived from
/// `SchedulerConfiguration` but decoupled so automation has no settings types.
public struct AutomationConfiguration: Sendable, Equatable {
    public var claudeAppPath: String?
    public var newChatShortcut: KeyboardShortcut
    public var launchDelay: TimeInterval
    public var newChatDelay: TimeInterval
    public var sendDelay: TimeInterval
    /// Whether Return should be pressed to actually send the message.
    public var pressReturn: Bool
    /// When `true`, perform every step except pressing Return (a safe preview).
    public var dryRun: Bool

    public init(
        claudeAppPath: String? = nil,
        newChatShortcut: KeyboardShortcut = .newChat,
        launchDelay: TimeInterval = 3.0,
        newChatDelay: TimeInterval = 1.5,
        sendDelay: TimeInterval = 0.8,
        pressReturn: Bool = true,
        dryRun: Bool = false
    ) {
        self.claudeAppPath = claudeAppPath
        self.newChatShortcut = newChatShortcut
        self.launchDelay = launchDelay
        self.newChatDelay = newChatDelay
        self.sendDelay = sendDelay
        self.pressReturn = pressReturn
        self.dryRun = dryRun
    }

    /// Builds an automation configuration from the persisted settings, allowing
    /// the trigger to override Return-pressing (for dry runs).
    public init(from config: SchedulerConfiguration, dryRun: Bool = false) {
        self.claudeAppPath = config.claudeAppPath
        self.newChatShortcut = config.newChatShortcut
        self.launchDelay = config.launchDelay
        self.newChatDelay = config.newChatDelay
        self.sendDelay = config.sendDelay
        self.pressReturn = config.pressReturnAutomatically && !dryRun
        self.dryRun = dryRun
    }
}

/// A structured record of which automation steps completed.
public struct AutomationResult: Codable, Sendable, Equatable {
    public var didLaunchClaude: Bool
    public var didActivate: Bool
    public var didOpenNewChat: Bool
    public var didPaste: Bool
    public var didSend: Bool
    public var duration: TimeInterval

    public init(
        didLaunchClaude: Bool = false,
        didActivate: Bool = false,
        didOpenNewChat: Bool = false,
        didPaste: Bool = false,
        didSend: Bool = false,
        duration: TimeInterval = 0
    ) {
        self.didLaunchClaude = didLaunchClaude
        self.didActivate = didActivate
        self.didOpenNewChat = didOpenNewChat
        self.didPaste = didPaste
        self.didSend = didSend
        self.duration = duration
    }
}
