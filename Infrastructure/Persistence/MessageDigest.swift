import Foundation
import CryptoKit

/// Derives privacy-preserving metadata about a message for logging. The message
/// itself is never stored; only a length, emptiness flag, and a short SHA-256
/// hash prefix (useful for spotting accidental changes) are produced.
public struct MessageDigest: Sendable, Equatable {
    public let characterCount: Int
    public let isEmpty: Bool
    public let hashPrefix: String?

    public init(message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.characterCount = message.count
        self.isEmpty = trimmed.isEmpty
        if trimmed.isEmpty {
            self.hashPrefix = nil
        } else {
            let digest = SHA256.hash(data: Data(message.utf8))
            // First 4 bytes is enough to detect a changed message without being
            // a reversible record of the content.
            self.hashPrefix = digest.prefix(4)
                .map { String(format: "%02x", $0) }
                .joined()
        }
    }
}
