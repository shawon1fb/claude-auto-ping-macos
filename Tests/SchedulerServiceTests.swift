import XCTest
@testable import ClaudeAutoPingMacos

@MainActor
final class SchedulerServiceTests: XCTestCase {
    // Initialized inline: XCTest creates a fresh test-case instance per test
    // method, so each test gets its own mocks. This also keeps initialization
    // on the @MainActor (the overridable `setUp()` is nonisolated under Swift 6).
    private var clock = MockClock()
    private var settings = MockSettingsStore()
    private var automation = MockAutomationService()
    private var logStore = MockLogStore()
    private var permission = MockPermissionService()
    private var notifications = MockNotificationService()
    private var systemState = MockSystemStateProvider()
    private var ticker = MockSchedulerTicker()
    private let fiveHours: TimeInterval = 5 * 60 * 60

    private func makeScheduler(
        configuration: SchedulerConfiguration = SchedulerConfiguration()
    ) -> DefaultSchedulerService {
        settings.configuration = configuration
        return DefaultSchedulerService(
            settingsStore: settings,
            automation: automation,
            logStore: logStore,
            clock: clock,
            permission: permission,
            notifications: notifications,
            systemState: systemState,
            ticker: ticker
        )
    }

    func testStartSchedulesFirstRunAndStartsTicker() {
        let scheduler = makeScheduler()
        scheduler.start()
        XCTAssertEqual(scheduler.status, .running)
        XCTAssertTrue(ticker.isRunning)
        XCTAssertEqual(scheduler.persistentState.nextScheduledDate, clock.now().addingTimeInterval(fiveHours))
        XCTAssertTrue(scheduler.configuration.isEnabled)
    }

    func testPauseAndResume() {
        let scheduler = makeScheduler()
        scheduler.start()
        scheduler.pause()
        XCTAssertEqual(scheduler.status, .paused)
        XCTAssertFalse(ticker.isRunning)
        scheduler.resume()
        XCTAssertEqual(scheduler.status, .running)
        XCTAssertTrue(ticker.isRunning)
    }

    func testStopClearsSchedule() {
        let scheduler = makeScheduler()
        scheduler.start()
        scheduler.stop()
        XCTAssertEqual(scheduler.status, .stopped)
        XCTAssertNil(scheduler.persistentState.nextScheduledDate)
        XCTAssertFalse(ticker.isRunning)
    }

    func testManualExecutionSendsAndLogs() async {
        let scheduler = makeScheduler()
        await scheduler.sendTestMessage()
        XCTAssertEqual(automation.callCount, 1)
        XCTAssertEqual(automation.lastMessage, "hi")
        let logs = await logStore.all()
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].success)
    }

    func testAutomaticExecutionWhenDue() async {
        let scheduler = makeScheduler()
        scheduler.start()
        clock.advance(by: fiveHours + 1)
        await scheduler.evaluate()
        XCTAssertEqual(automation.callCount, 1)
        // Next run is rescheduled into the future.
        XCTAssertGreaterThan(scheduler.persistentState.nextScheduledDate ?? .distantPast, clock.now())
    }

    func testEvaluateDoesNothingWhenNotDue() async {
        let scheduler = makeScheduler()
        scheduler.start()
        await scheduler.evaluate() // now < next
        XCTAssertEqual(automation.callCount, 0)
    }

    func testFiringTickerEvaluates() async {
        let scheduler = makeScheduler()
        scheduler.start()
        clock.advance(by: fiveHours + 1)
        ticker.fire()
        // The ticker dispatches an async Task; yield until it completes.
        await waitForCallCount(1)
        XCTAssertEqual(automation.callCount, 1)
    }

    func testPauseAfterThreeConsecutiveFailures() async {
        automation.errorToThrow = .sendFailed
        let scheduler = makeScheduler()
        scheduler.start()
        for _ in 0..<3 {
            clock.advance(by: fiveHours + 1)
            await scheduler.evaluate()
        }
        XCTAssertEqual(automation.callCount, 3)
        XCTAssertTrue(scheduler.persistentState.pausedDueToFailures)
        if case .error = scheduler.status {} else {
            XCTFail("Expected error status after repeated failures")
        }
        XCTAssertFalse(ticker.isRunning)
    }

    func testSuccessResetsFailureCount() async {
        automation.errorToThrow = .sendFailed
        let scheduler = makeScheduler()
        scheduler.start()
        clock.advance(by: fiveHours + 1)
        await scheduler.evaluate()
        XCTAssertEqual(scheduler.persistentState.consecutiveFailures, 1)
        automation.errorToThrow = nil
        clock.advance(by: fiveHours + 1)
        await scheduler.evaluate()
        XCTAssertEqual(scheduler.persistentState.consecutiveFailures, 0)
    }

    func testDuplicatePreventionBlocksSecondImmediateSend() async {
        let scheduler = makeScheduler()
        await scheduler.sendTestMessage()
        await scheduler.sendTestMessage() // within cooldown, same clock
        XCTAssertEqual(automation.callCount, 1)
        let logs = await logStore.all()
        XCTAssertEqual(logs.count, 2)
        XCTAssertFalse(logs[0].success) // the blocked one
    }

    func testWakeRecoverySendsAtMostOnce() async {
        let scheduler = makeScheduler()
        scheduler.start()
        // Simulate a long sleep spanning several intervals.
        clock.advance(by: fiveHours * 3 + 60)
        await scheduler.handleWake()
        XCTAssertEqual(automation.callCount, 1)
        XCTAssertGreaterThan(scheduler.persistentState.nextScheduledDate ?? .distantPast, clock.now())
    }

    func testWakeRecoveryDisabledDoesNotSend() async {
        var config = SchedulerConfiguration()
        config.wakeRecoveryEnabled = false
        let scheduler = makeScheduler(configuration: config)
        scheduler.start()
        clock.advance(by: fiveHours * 2 + 60)
        await scheduler.handleWake()
        XCTAssertEqual(automation.callCount, 0)
        // Schedule realigned to the future without sending.
        XCTAssertGreaterThan(scheduler.persistentState.nextScheduledDate ?? .distantPast, clock.now())
    }

    func testPermissionRequiredBlocksSend() async {
        permission.status = .denied
        let scheduler = makeScheduler()
        await scheduler.sendTestMessage()
        XCTAssertEqual(automation.callCount, 0)
        XCTAssertEqual(scheduler.status, .permissionRequired)
        let logs = await logStore.all()
        XCTAssertEqual(logs.first?.success, false)
    }

    func testScreenLockedSkipsSend() async {
        systemState.locked = true
        let scheduler = makeScheduler()
        scheduler.start()
        clock.advance(by: fiveHours + 1)
        await scheduler.evaluate()
        XCTAssertEqual(automation.callCount, 0)
        let logs = await logStore.all()
        XCTAssertEqual(logs.first?.errorDescription, AutomationError.screenLocked.errorDescription)
    }

    func testEmptyMessageIsNotSent() async {
        var config = SchedulerConfiguration()
        config.message = "   "
        let scheduler = makeScheduler(configuration: config)
        await scheduler.sendTestMessage()
        XCTAssertEqual(automation.callCount, 0)
        let logs = await logStore.all()
        XCTAssertEqual(logs.first?.success, false)
    }

    func testUpdatingIntervalReschedules() {
        let scheduler = makeScheduler()
        scheduler.start()
        let originalNext = scheduler.persistentState.nextScheduledDate
        var config = scheduler.configuration
        config.intervalPreset = .oneHour
        scheduler.updateConfiguration(config)
        XCTAssertNotEqual(scheduler.persistentState.nextScheduledDate, originalNext)
        XCTAssertEqual(scheduler.persistentState.nextScheduledDate, clock.now().addingTimeInterval(60 * 60))
    }

    func testAnchoredScheduleUsesResetTime() async {
        var config = SchedulerConfiguration()
        let anchor = clock.now().addingTimeInterval(3600) // reset at now + 1h
        config.anchorToResetTime = true
        config.resetAnchorDate = anchor
        let scheduler = makeScheduler(configuration: config)
        scheduler.start()
        // First send lands on the reset time, not now + interval.
        XCTAssertEqual(scheduler.persistentState.nextScheduledDate, anchor)

        clock.set(anchor)
        await scheduler.evaluate()
        XCTAssertEqual(automation.callCount, 1)
        // After sending, the next send is one interval after the reset, staying
        // locked to the reset cadence.
        XCTAssertEqual(
            scheduler.persistentState.nextScheduledDate,
            anchor.addingTimeInterval(fiveHours)
        )
    }

    func testUnanchoredScheduleUsesNowPlusInterval() {
        var config = SchedulerConfiguration()
        config.anchorToResetTime = false
        let scheduler = makeScheduler(configuration: config)
        scheduler.start()
        XCTAssertEqual(
            scheduler.persistentState.nextScheduledDate,
            clock.now().addingTimeInterval(fiveHours)
        )
    }

    func testDryRunDoesNotRecordSuccessDate() async {
        let scheduler = makeScheduler()
        await scheduler.runDryTest()
        XCTAssertEqual(automation.callCount, 1)
        XCTAssertNil(scheduler.persistentState.lastSuccessDate)
    }

    // MARK: - Helpers

    private func waitForCallCount(_ expected: Int, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while automation.callCount < expected, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
