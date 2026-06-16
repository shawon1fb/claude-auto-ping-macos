import Foundation
@testable import ClaudeAutoPingMacos

// MARK: - Clock

final class MockClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.current = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        current = date
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}

// MARK: - Settings store

final class MockSettingsStore: SettingsStore, @unchecked Sendable {
    var configuration: SchedulerConfiguration
    var state: SchedulerPersistentState

    init(
        configuration: SchedulerConfiguration = SchedulerConfiguration(),
        state: SchedulerPersistentState = SchedulerPersistentState()
    ) {
        self.configuration = configuration
        self.state = state
    }

    func loadConfiguration() -> SchedulerConfiguration { configuration }
    func saveConfiguration(_ configuration: SchedulerConfiguration) { self.configuration = configuration }
    func loadState() -> SchedulerPersistentState { state }
    func saveState(_ state: SchedulerPersistentState) { self.state = state }
    func reset() {
        configuration = SchedulerConfiguration()
        state = SchedulerPersistentState()
    }
}

// MARK: - Automation service

final class MockAutomationService: AutomationService, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private var _lastMessage: String?

    var resultToReturn = AutomationResult(didOpenNewChat: true, didPaste: true, didSend: true, duration: 0.1)
    var errorToThrow: AutomationError?

    var callCount: Int { lock.lock(); defer { lock.unlock() }; return _callCount }
    var lastMessage: String? { lock.lock(); defer { lock.unlock() }; return _lastMessage }

    func sendMessage(_ message: String, configuration: AutomationConfiguration) async throws -> AutomationResult {
        let (error, result): (AutomationError?, AutomationResult) = lock.withLock {
            _callCount += 1
            _lastMessage = message
            return (errorToThrow, resultToReturn)
        }
        if let error { throw error }
        return result
    }
}

// MARK: - Log store

actor MockLogStore: LogStore {
    nonisolated let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
    private var entries: [LogEntry] = []

    func append(_ entry: LogEntry, retentionCount: Int) {
        entries.insert(entry, at: 0)
        if entries.count > retentionCount {
            entries.removeLast(entries.count - retentionCount)
        }
    }

    func all() -> [LogEntry] { entries }
    func clear() { entries.removeAll() }
    func exportJSON() throws -> Data { try JSONEncoder().encode(entries) }
}

// MARK: - Permission service

@MainActor
final class MockPermissionService: PermissionService {
    var status: PermissionStatus = .granted
    var automation: PermissionStatus = .granted
    private(set) var promptCount = 0

    func accessibilityStatus() -> PermissionStatus { status }
    func automationStatus() -> PermissionStatus { automation }
    func requestAccessibilityPrompt() { promptCount += 1 }
    func openAccessibilitySettings() {}
    func openAutomationSettings() {}
}

// MARK: - Notification service

final class MockNotificationService: NotificationService, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var messages: [(title: String, body: String)] = []

    func requestAuthorization() {}
    func notify(title: String, body: String) {
        lock.lock(); defer { lock.unlock() }
        messages.append((title, body))
    }
}

// MARK: - System state

final class MockSystemStateProvider: SystemStateProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _locked: Bool
    init(locked: Bool = false) { self._locked = locked }
    var locked: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _locked }
        set { lock.lock(); defer { lock.unlock() }; _locked = newValue }
    }
    func isScreenLocked() -> Bool { locked }
}

// MARK: - Ticker

@MainActor
final class MockSchedulerTicker: SchedulerTicker {
    private(set) var isRunning = false
    private var tick: (@MainActor () -> Void)?

    func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
        isRunning = true
        self.tick = tick
    }

    func stop() {
        isRunning = false
        tick = nil
    }

    /// Manually fires the stored tick, simulating a timer firing.
    func fire() { tick?() }
}

// MARK: - Claude app controller

final class MockClaudeAppController: ClaudeAppController, @unchecked Sendable {
    private let lock = NSLock()
    private var _prepareCount = 0
    var didLaunch = false
    var errorToThrow: AutomationError?

    var prepareCount: Int { lock.lock(); defer { lock.unlock() }; return _prepareCount }

    func prepare(preferredPath: String?, launchDelay: TimeInterval) async throws -> Bool {
        let (error, launched): (AutomationError?, Bool) = lock.withLock {
            _prepareCount += 1
            return (errorToThrow, didLaunch)
        }
        if let error { throw error }
        return launched
    }
}

// MARK: - AppleScript runner

final class MockAppleScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var sources: [String] = []
    /// When a run's source contains this substring, throw `errorToThrow`.
    var failOnSubstring: String?
    var errorToThrow: AutomationError = .scriptFailed("mock failure")

    @discardableResult
    func run(_ source: String) throws -> String? {
        lock.lock()
        sources.append(source)
        let fail = failOnSubstring.map { source.contains($0) } ?? false
        let error = errorToThrow
        lock.unlock()
        if fail { throw error }
        return nil
    }
}

// MARK: - Clipboard

final class MockClipboardManager: ClipboardManager, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var snapshotCount = 0
    private(set) var restoreCount = 0
    private(set) var setStrings: [String] = []
    var failSetString = false

    func snapshot() -> ClipboardSnapshot {
        lock.lock(); defer { lock.unlock() }
        snapshotCount += 1
        return ClipboardSnapshot(items: ["public.utf8-plain-text": Data("original".utf8)])
    }

    func setString(_ string: String) throws {
        lock.lock()
        let shouldFail = failSetString
        if !shouldFail { setStrings.append(string) }
        lock.unlock()
        if shouldFail { throw AutomationError.clipboardWriteFailed }
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        lock.lock(); defer { lock.unlock() }
        restoreCount += 1
    }

    var lastSetString: String? { lock.lock(); defer { lock.unlock() }; return setStrings.last }
}
