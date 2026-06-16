import Foundation
import OSLog

/// `LogStore` that persists entries as a JSON file in Application Support and
/// keeps an in-memory cache. An actor serializes all access so concurrent
/// appends from automation and the UI cannot corrupt the file.
public actor FileLogStore: LogStore {
    public nonisolated let directoryURL: URL
    private let fileURL: URL
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "LogStore")
    private var cache: [LogEntry]
    private var loaded = false

    public init(directoryURL: URL = AppInfo.supportDirectoryURL) {
        self.directoryURL = directoryURL
        self.fileURL = directoryURL.appendingPathComponent("logs.json")
        self.cache = []
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            cache = try JSONDecoder().decode([LogEntry].self, from: data)
        } catch {
            logger.error("Failed to decode logs; starting empty: \(error.localizedDescription, privacy: .public)")
            cache = []
        }
    }

    public func append(_ entry: LogEntry, retentionCount: Int) {
        loadIfNeeded()
        cache.insert(entry, at: 0)
        let limit = max(1, retentionCount)
        if cache.count > limit {
            cache.removeLast(cache.count - limit)
        }
        persist()
    }

    public func all() -> [LogEntry] {
        loadIfNeeded()
        return cache
    }

    public func clear() {
        loadIfNeeded()
        cache.removeAll()
        persist()
    }

    public func exportJSON() throws -> Data {
        loadIfNeeded()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(cache)
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to persist logs: \(error.localizedDescription, privacy: .public)")
        }
    }
}
