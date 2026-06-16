import Foundation

/// Persisted runtime tracking for the scheduler, kept separate from
/// user-configurable settings. Survives app relaunches so duplicate protection
/// and missed-execution handling work across restarts.
public struct SchedulerPersistentState: Codable, Sendable, Equatable {
    /// The next time an execution is due, or `nil` when the scheduler is idle.
    public var nextScheduledDate: Date?
    /// The last time an execution was attempted (success or failure).
    public var lastAttemptDate: Date?
    /// The last time a message was sent successfully.
    public var lastSuccessDate: Date?
    /// The last time an execution failed.
    public var lastFailureDate: Date?
    /// Consecutive automation failures; resets to zero on success.
    public var consecutiveFailures: Int
    /// Whether the scheduler was auto-paused after repeated failures.
    public var pausedDueToFailures: Bool
    /// Whether the user paused the scheduler manually.
    public var isPaused: Bool

    public init(
        nextScheduledDate: Date? = nil,
        lastAttemptDate: Date? = nil,
        lastSuccessDate: Date? = nil,
        lastFailureDate: Date? = nil,
        consecutiveFailures: Int = 0,
        pausedDueToFailures: Bool = false,
        isPaused: Bool = false
    ) {
        self.nextScheduledDate = nextScheduledDate
        self.lastAttemptDate = lastAttemptDate
        self.lastSuccessDate = lastSuccessDate
        self.lastFailureDate = lastFailureDate
        self.consecutiveFailures = consecutiveFailures
        self.pausedDueToFailures = pausedDueToFailures
        self.isPaused = isPaused
    }
}
