import XCTest
@testable import ClaudeAutoPingMacos

final class ScheduleCalculatorTests: XCTestCase {
    private let calculator = ScheduleCalculator()
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private let fiveHours: TimeInterval = 5 * 60 * 60

    func testFirstExecutionDate() {
        let next = calculator.firstExecutionDate(from: base, interval: fiveHours)
        XCTAssertEqual(next, base.addingTimeInterval(fiveHours))
    }

    func testIsDue() {
        let scheduled = base.addingTimeInterval(100)
        XCTAssertFalse(calculator.isDue(scheduled: scheduled, now: base))
        XCTAssertTrue(calculator.isDue(scheduled: scheduled, now: scheduled))
        XCTAssertTrue(calculator.isDue(scheduled: scheduled, now: scheduled.addingTimeInterval(1)))
    }

    func testCustomInterval() {
        let interval: TimeInterval = 90 * 60
        let next = calculator.firstExecutionDate(from: base, interval: interval)
        XCTAssertEqual(next, base.addingTimeInterval(interval))
    }

    func testRepeatingIntervalKeepsCadence() {
        // One period elapsed exactly: next is the following slot.
        let scheduled = base
        let now = base.addingTimeInterval(fiveHours)
        let next = calculator.nextAligned(after: scheduled, now: now, interval: fiveHours)
        XCTAssertEqual(next, base.addingTimeInterval(2 * fiveHours))
    }

    func testMissedManyPeriodsCollapsesToSingleFutureSlot() {
        // 3.5 periods elapsed (sleep gap): next is the 4th slot, only one ahead.
        let scheduled = base
        let now = base.addingTimeInterval(fiveHours * 3.5)
        let next = calculator.nextAligned(after: scheduled, now: now, interval: fiveHours)
        XCTAssertEqual(next, base.addingTimeInterval(fiveHours * 4))
        XCTAssertGreaterThan(next, now)
    }

    func testResolveMissedWhenOverdue() {
        let scheduledNext = base
        let now = base.addingTimeInterval(fiveHours * 2 + 60)
        let resolution = calculator.resolveMissed(scheduledNext: scheduledNext, now: now, interval: fiveHours)
        XCTAssertTrue(resolution.shouldSendNow)
        XCTAssertGreaterThan(resolution.nextDate, now)
        // Exactly one future slot, not a backlog.
        XCTAssertEqual(resolution.nextDate, base.addingTimeInterval(fiveHours * 3))
    }

    func testResolveMissedWhenNotDue() {
        let scheduledNext = base.addingTimeInterval(fiveHours)
        let now = base
        let resolution = calculator.resolveMissed(scheduledNext: scheduledNext, now: now, interval: fiveHours)
        XCTAssertFalse(resolution.shouldSendNow)
        XCTAssertEqual(resolution.nextDate, scheduledNext)
    }

    func testInvalidIntervalIsClamped() {
        XCTAssertEqual(calculator.sanitizedInterval(0), SchedulerConfiguration.minimumIntervalSeconds)
        XCTAssertEqual(calculator.sanitizedInterval(-10), SchedulerConfiguration.minimumIntervalSeconds)
        XCTAssertEqual(calculator.sanitizedInterval(60), SchedulerConfiguration.minimumIntervalSeconds)
        XCTAssertEqual(calculator.sanitizedInterval(fiveHours), fiveHours)
    }

    func testDaylightSavingImmunity() {
        // Absolute-second intervals are immune to wall-clock DST shifts: adding
        // the interval always advances by exactly the interval.
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 9 // US DST spring-forward date
        components.hour = 1
        let calendar = Calendar(identifier: .gregorian)
        let preTransition = calendar.date(from: components) ?? base
        let next = calculator.firstExecutionDate(from: preTransition, interval: fiveHours)
        XCTAssertEqual(next.timeIntervalSince(preTransition), fiveHours, accuracy: 0.001)
    }

    func testClockMovingBackward() {
        // now earlier than the scheduled date: keep the scheduled date.
        let scheduled = base.addingTimeInterval(fiveHours)
        let now = base.addingTimeInterval(-fiveHours)
        let next = calculator.nextAligned(after: scheduled, now: now, interval: fiveHours)
        XCTAssertEqual(next, scheduled)
    }

    func testClockMovingForward() {
        let scheduled = base
        let now = base.addingTimeInterval(fiveHours * 10)
        let next = calculator.nextAligned(after: scheduled, now: now, interval: fiveHours)
        XCTAssertGreaterThan(next, now)
        XCTAssertEqual(next, base.addingTimeInterval(fiveHours * 11))
    }

    func testCooldownWindow() {
        let last = base
        XCTAssertTrue(calculator.isWithinCooldown(lastAttempt: last, now: base.addingTimeInterval(60), cooldown: 300))
        XCTAssertFalse(calculator.isWithinCooldown(lastAttempt: last, now: base.addingTimeInterval(301), cooldown: 300))
        XCTAssertFalse(calculator.isWithinCooldown(lastAttempt: nil, now: base, cooldown: 300))
        // Clock moved backward is treated as within cooldown (no surprise send).
        XCTAssertTrue(calculator.isWithinCooldown(lastAttempt: last, now: base.addingTimeInterval(-10), cooldown: 300))
    }
}
