import Foundation
import Observation

/// Loads and manages the execution log for display. Reads happen off the main
/// actor inside the `LogStore` actor; this view model just coordinates refresh,
/// clear, and export.
@MainActor
@Observable
public final class LogsViewModel {
    @ObservationIgnored private let logStore: LogStore

    public private(set) var entries: [LogEntry] = []
    public private(set) var isLoading = false

    public init(logStore: LogStore) {
        self.logStore = logStore
    }

    public func refresh() async {
        isLoading = true
        entries = await logStore.all()
        isLoading = false
    }

    public func clear() async {
        await logStore.clear()
        await refresh()
    }

    public func exportJSON() async -> Data? {
        try? await logStore.exportJSON()
    }
}
