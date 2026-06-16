import Foundation
import Observation

/// Presentation logic for the menu bar popover. Formats scheduler state into
/// display strings and exposes the user actions, so the view stays declarative
/// and free of business logic.
@MainActor
@Observable
public final class MenuBarViewModel {
    @ObservationIgnored private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    private var scheduler: DefaultSchedulerService { environment.scheduler }

    public var status: SchedulerStatus { scheduler.status }

    public var nextRunText: String {
        guard scheduler.status.isActive,
              let next = scheduler.persistentState.nextScheduledDate else {
            return "—"
        }
        return DateDisplay.dateTimeString(next)
    }

    public var intervalText: String {
        DateDisplay.intervalDescription(scheduler.configuration.effectiveIntervalSeconds)
    }

    public var messagePreview: String {
        let message = scheduler.configuration.trimmedMessage
        return message.isEmpty ? "(empty)" : message
    }

    public var lastResultText: String {
        let state = scheduler.persistentState
        if let success = state.lastSuccessDate,
           success >= (state.lastFailureDate ?? .distantPast) {
            return "Sent at \(DateDisplay.dateTimeString(success))"
        }
        if let failure = state.lastFailureDate {
            return "Failed at \(DateDisplay.dateTimeString(failure))"
        }
        return "No runs yet"
    }

    // MARK: Reset window

    public var anchorToResetTime: Bool { scheduler.configuration.anchorToResetTime }

    public var resetTime: Date {
        scheduler.configuration.resetAnchorDate ?? Self.defaultResetTime()
    }

    public var hasResetTime: Bool {
        scheduler.configuration.resetAnchorDate != nil
    }

    public func setAnchorToResetTime(_ enabled: Bool) {
        var config = scheduler.configuration
        config.anchorToResetTime = enabled
        if enabled, config.resetAnchorDate == nil {
            config.resetAnchorDate = Self.defaultResetTime()
        }
        scheduler.updateConfiguration(config)
    }

    public func setResetTime(_ date: Date) {
        var config = scheduler.configuration
        config.resetAnchorDate = date
        config.anchorToResetTime = true
        scheduler.updateConfiguration(config)
    }

    /// The next top of the hour, used as a sensible default reset time.
    public static func defaultResetTime() -> Date {
        Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date()
    }

    public var canPause: Bool { scheduler.status.isActive }
    public var canResume: Bool {
        if case .running = scheduler.status { return false }
        return scheduler.configuration.isEnabled || isPausedOrError
    }

    private var isPausedOrError: Bool {
        switch scheduler.status {
        case .paused, .error: return true
        default: return false
        }
    }

    public var isStopped: Bool { scheduler.status == .stopped }

    // MARK: Actions

    public func start() { scheduler.start() }
    public func pause() { scheduler.pause() }
    public func resume() { scheduler.resume() }
    public func stop() { scheduler.stop() }
    public func sendTest() async { await scheduler.sendTestMessage() }
}
