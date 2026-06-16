import Foundation

/// A privacy-preserving record of a single automation run. The configured
/// message content is never stored; only a character count, an optional hash
/// prefix, and an emptiness flag are kept.
public struct LogEntry: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let trigger: TriggerSource
    public let success: Bool

    // Privacy-preserving message metadata.
    public let messageCharacterCount: Int
    public let messageHashPrefix: String?
    public let messageWasEmpty: Bool

    // Step outcomes.
    public let didLaunchClaude: Bool
    public let didOpenNewChat: Bool
    public let didPaste: Bool
    public let didSend: Bool
    public let duration: TimeInterval

    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        trigger: TriggerSource,
        success: Bool,
        messageCharacterCount: Int,
        messageHashPrefix: String?,
        messageWasEmpty: Bool,
        didLaunchClaude: Bool,
        didOpenNewChat: Bool,
        didPaste: Bool,
        didSend: Bool,
        duration: TimeInterval,
        errorDescription: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.trigger = trigger
        self.success = success
        self.messageCharacterCount = messageCharacterCount
        self.messageHashPrefix = messageHashPrefix
        self.messageWasEmpty = messageWasEmpty
        self.didLaunchClaude = didLaunchClaude
        self.didOpenNewChat = didOpenNewChat
        self.didPaste = didPaste
        self.didSend = didSend
        self.duration = duration
        self.errorDescription = errorDescription
    }
}
