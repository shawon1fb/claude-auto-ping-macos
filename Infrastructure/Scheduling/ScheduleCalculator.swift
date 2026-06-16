import Foundation

/// The result of resolving a potentially-missed execution after the Mac wakes
/// or the app relaunches.
public struct MissedResolution: Sendable, Equatable {
    /// Whether a single catch-up send should happen now.
    public var shouldSendNow: Bool
    /// The next scheduled execution date after resolving.
    public var nextDate: Date

    public init(shouldSendNow: Bool, nextDate: Date) {
        self.shouldSendNow = shouldSendNow
        self.nextDate = nextDate
    }
}

/// Pure, deterministic scheduling math. Has no dependency on timers, the system
/// clock, or any framework, so every branch is unit-testable. Intervals are
/// absolute seconds, which makes the calculator immune to daylight-saving
/// transitions.
public struct ScheduleCalculator: Sendable {
    public init() {}

    /// Clamps an interval to the supported minimum, guarding against zero or
    /// negative values that could cause a tight scheduling loop.
    public func sanitizedInterval(_ interval: TimeInterval) -> TimeInterval {
        guard interval.isFinite, interval > 0 else {
            return SchedulerConfiguration.minimumIntervalSeconds
        }
        return max(interval, SchedulerConfiguration.minimumIntervalSeconds)
    }

    /// The first execution after starting the scheduler at `start`.
    public func firstExecutionDate(from start: Date, interval: TimeInterval) -> Date {
        start.addingTimeInterval(sanitizedInterval(interval))
    }

    /// Whether an execution scheduled for `scheduled` is due at `now`.
    public func isDue(scheduled: Date, now: Date) -> Bool {
        now >= scheduled
    }

    /// The next execution date that is strictly in the future relative to `now`,
    /// staying aligned to the original cadence anchored at `scheduled`.
    ///
    /// This prevents two failure modes: drift (recomputing from `now` each time)
    /// and stacking (returning a past date that immediately re-fires). If many
    /// periods were missed, it skips forward to the next single future slot.
    public func nextAligned(after scheduled: Date, now: Date, interval: TimeInterval) -> Date {
        let step = sanitizedInterval(interval)
        if scheduled > now {
            return scheduled
        }
        let elapsed = now.timeIntervalSince(scheduled)
        let periods = (elapsed / step).rounded(.down) + 1
        return scheduled.addingTimeInterval(periods * step)
    }

    /// Resolves whether a single catch-up send is warranted after a gap (sleep,
    /// logout, relaunch). At most one send is ever indicated, and the returned
    /// `nextDate` is always in the future, preventing queued missed messages.
    public func resolveMissed(
        scheduledNext: Date,
        now: Date,
        interval: TimeInterval
    ) -> MissedResolution {
        let due = isDue(scheduled: scheduledNext, now: now)
        let next = nextAligned(after: scheduledNext, now: now, interval: interval)
        return MissedResolution(shouldSendNow: due, nextDate: next)
    }

    /// Whether a send at `now` is blocked by the duplicate-protection cooldown,
    /// given the last attempt time. A `nil` last attempt never blocks.
    public func isWithinCooldown(
        lastAttempt: Date?,
        now: Date,
        cooldown: TimeInterval
    ) -> Bool {
        guard let lastAttempt, cooldown > 0 else { return false }
        let delta = now.timeIntervalSince(lastAttempt)
        // A clock moving backward (now < lastAttempt) is treated as within the
        // cooldown to avoid an unexpected immediate re-send.
        if delta < 0 { return true }
        return delta < cooldown
    }
}
