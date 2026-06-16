import Foundation

/// A bounded, persistent store of execution logs. Implementations cap the
/// number of retained entries and never store private message content.
public protocol LogStore: Sendable {
    /// Appends an entry, trimming to `retentionCount` newest records.
    func append(_ entry: LogEntry, retentionCount: Int) async
    /// All retained entries, newest first.
    func all() async -> [LogEntry]
    func clear() async
    /// Pretty-printed JSON of all retained entries.
    func exportJSON() async throws -> Data
    /// The directory where logs are stored on disk.
    var directoryURL: URL { get }
}
