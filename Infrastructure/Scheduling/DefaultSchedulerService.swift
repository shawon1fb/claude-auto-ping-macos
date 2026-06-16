import Foundation
import Observation
import OSLog

/// The production scheduler. It owns timing, duplicate protection, missed-run
/// recovery, failure tracking, and logging, delegating the actual UI work to an
/// injected `AutomationService`. All time comes from an injected `Clock` and all
/// periodic ticks from an injected `SchedulerTicker`, so behavior is fully
/// deterministic in tests.
@MainActor
@Observable
public final class DefaultSchedulerService: SchedulerService {
    public private(set) var status: SchedulerStatus = .stopped
    public private(set) var configuration: SchedulerConfiguration
    public private(set) var persistentState: SchedulerPersistentState

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let automation: AutomationService
    @ObservationIgnored private let logStore: LogStore
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let permission: PermissionService
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let systemState: SystemStateProvider
    @ObservationIgnored private let ticker: SchedulerTicker
    @ObservationIgnored private let calculator = ScheduleCalculator()
    @ObservationIgnored private let logger = Logger(subsystem: AppInfo.subsystem, category: "Scheduler")

    /// Consecutive automatic failures that trigger an auto-pause.
    @ObservationIgnored private let maxConsecutiveFailures = 3
    /// How often the ticker evaluates whether a run is due.
    @ObservationIgnored private let tickInterval: TimeInterval = 15
    /// Guards against overlapping runs (double timers, wake + tick races).
    @ObservationIgnored private var isExecuting = false

    public init(
        settingsStore: SettingsStore,
        automation: AutomationService,
        logStore: LogStore,
        clock: Clock,
        permission: PermissionService,
        notifications: NotificationService,
        systemState: SystemStateProvider,
        ticker: SchedulerTicker
    ) {
        self.settingsStore = settingsStore
        self.automation = automation
        self.logStore = logStore
        self.clock = clock
        self.permission = permission
        self.notifications = notifications
        self.systemState = systemState
        self.ticker = ticker
        self.configuration = settingsStore.loadConfiguration()
        self.persistentState = settingsStore.loadState()
        recomputeStatus()
    }

    /// Resumes timing if the scheduler was already enabled before launch. Call
    /// once at startup after dependencies are wired.
    public func activate() {
        guard configuration.isEnabled, !persistentState.isPaused, !persistentState.pausedDueToFailures else {
            recomputeStatus()
            return
        }
        if persistentState.nextScheduledDate == nil {
            persistentState.nextScheduledDate = calculator.firstExecutionDate(
                from: clock.now(),
                interval: configuration.effectiveIntervalSeconds
            )
        }
        persist()
        startTicker()
        recomputeStatus()
    }

    // MARK: - Lifecycle

    public func start() {
        configuration.isEnabled = true
        persistentState.isPaused = false
        persistentState.pausedDueToFailures = false
        persistentState.consecutiveFailures = 0
        persistentState.nextScheduledDate = calculator.firstExecutionDate(
            from: clock.now(),
            interval: configuration.effectiveIntervalSeconds
        )
        persist()
        startTicker()
        recomputeStatus()
        logger.info("Scheduler started; next run \(self.persistentState.nextScheduledDate?.description ?? "n/a", privacy: .public)")
    }

    public func pause() {
        persistentState.isPaused = true
        ticker.stop()
        persist()
        recomputeStatus()
        logger.info("Scheduler paused")
    }

    public func resume() {
        guard configuration.isEnabled else { start(); return }
        persistentState.isPaused = false
        persistentState.pausedDueToFailures = false
        persistentState.consecutiveFailures = 0
        if persistentState.nextScheduledDate == nil {
            persistentState.nextScheduledDate = calculator.firstExecutionDate(
                from: clock.now(),
                interval: configuration.effectiveIntervalSeconds
            )
        }
        persist()
        startTicker()
        recomputeStatus()
        logger.info("Scheduler resumed")
    }

    public func stop() {
        configuration.isEnabled = false
        persistentState.isPaused = false
        persistentState.pausedDueToFailures = false
        persistentState.consecutiveFailures = 0
        persistentState.nextScheduledDate = nil
        ticker.stop()
        persist()
        recomputeStatus()
        logger.info("Scheduler stopped")
    }

    public func updateConfiguration(_ configuration: SchedulerConfiguration) {
        let intervalChanged = configuration.effectiveIntervalSeconds != self.configuration.effectiveIntervalSeconds
        self.configuration = configuration
        // Recompute the next run if the interval changed while active.
        if intervalChanged, self.configuration.isEnabled, !persistentState.isPaused {
            persistentState.nextScheduledDate = calculator.firstExecutionDate(
                from: clock.now(),
                interval: configuration.effectiveIntervalSeconds
            )
        }
        persist()
        recomputeStatus()
    }

    // MARK: - Evaluation entry points

    /// Periodic check used by the ticker. Sends only when a run is genuinely due.
    public func evaluate() async {
        guard isRunningState else { return }
        guard let next = persistentState.nextScheduledDate else { return }
        guard calculator.isDue(scheduled: next, now: clock.now()) else { return }
        await performRun(trigger: .scheduledTimer)
    }

    public func sendTestMessage() async {
        await performRun(trigger: .manualTest)
    }

    public func runDryTest() async {
        await performRun(trigger: .dryRun, dryRun: true)
    }

    public func handleWake() async {
        guard isRunningState else { return }
        guard let next = persistentState.nextScheduledDate else { return }
        let now = clock.now()
        let resolution = calculator.resolveMissed(
            scheduledNext: next,
            now: now,
            interval: configuration.effectiveIntervalSeconds
        )
        if resolution.shouldSendNow, configuration.wakeRecoveryEnabled {
            await performRun(trigger: .wakeRecovery)
        } else {
            // Either not due, or wake recovery is disabled: realign to a future
            // slot without sending, so no burst of missed messages occurs.
            persistentState.nextScheduledDate = resolution.nextDate
            persist()
        }
    }

    // MARK: - Core run

    private func performRun(trigger: TriggerSource, dryRun: Bool = false) async {
        guard !isExecuting else {
            logger.notice("Run skipped; another execution is in progress")
            return
        }
        isExecuting = true
        defer { isExecuting = false }

        let now = clock.now()
        let isAutomatic = trigger == .scheduledTimer || trigger == .wakeRecovery

        // Duplicate protection (does not apply to dry runs, which never send).
        if !dryRun, calculator.isWithinCooldown(
            lastAttempt: persistentState.lastAttemptDate,
            now: now,
            cooldown: configuration.duplicateCooldown
        ) {
            await record(trigger: trigger, success: false, result: nil,
                         error: .duplicateExecutionBlocked, at: now)
            if isAutomatic { rescheduleNext(from: now) }
            return
        }

        // Empty messages are never sent.
        let message = configuration.message
        if configuration.trimmedMessage.isEmpty {
            await record(trigger: trigger, success: false, result: nil,
                         error: .invalidConfiguration("The message is empty."), at: now)
            if isAutomatic { rescheduleNext(from: now) }
            return
        }

        // Accessibility permission is required to drive other apps.
        if permission.accessibilityStatus() != .granted {
            await record(trigger: trigger, success: false, result: nil,
                         error: .accessibilityPermissionDenied, at: now)
            status = .permissionRequired
            if configuration.notifyOnFailure {
                notifications.notify(title: AppInfo.displayName,
                                     body: "Accessibility permission is required to send messages.")
            }
            if isAutomatic { rescheduleNext(from: now) }
            return
        }

        // Do not attempt UI automation while the screen is locked.
        if systemState.isScreenLocked() {
            await record(trigger: trigger, success: false, result: nil,
                         error: .screenLocked, at: now)
            if isAutomatic { rescheduleNext(from: now) }
            return
        }

        persistentState.lastAttemptDate = now
        persist()

        do {
            let autoConfig = AutomationConfiguration(from: configuration, dryRun: dryRun)
            let result = try await automation.sendMessage(message, configuration: autoConfig)
            persistentState.consecutiveFailures = 0
            if !dryRun {
                persistentState.lastSuccessDate = clock.now()
            }
            await record(trigger: trigger, success: true, result: result, error: nil, at: now)
            if !dryRun, configuration.notifyOnSuccess {
                notifications.notify(title: AppInfo.displayName, body: "Message sent successfully.")
            }
            if isAutomatic { rescheduleNext(from: now) }
            recomputeStatus()
        } catch {
            let automationError = (error as? AutomationError) ?? .scriptFailed(error.localizedDescription)
            persistentState.lastFailureDate = clock.now()
            await record(trigger: trigger, success: false, result: nil, error: automationError, at: now)
            if configuration.notifyOnFailure {
                notifications.notify(title: AppInfo.displayName,
                                     body: automationError.errorDescription ?? "Sending failed.")
            }
            // Only automatic runs count toward the auto-pause safety limit.
            if isAutomatic {
                persistentState.consecutiveFailures += 1
                if persistentState.consecutiveFailures >= maxConsecutiveFailures {
                    pauseDueToFailures()
                } else {
                    rescheduleNext(from: now)
                }
            }
            recomputeStatus()
        }
        persist()
    }

    private func pauseDueToFailures() {
        persistentState.pausedDueToFailures = true
        ticker.stop()
        status = .error("Paused after \(maxConsecutiveFailures) consecutive failures.")
        notifications.notify(
            title: AppInfo.displayName,
            body: "Automatic sending paused after repeated failures. Run a test to resume."
        )
        logger.error("Auto-paused after \(self.maxConsecutiveFailures) consecutive failures")
    }

    private func rescheduleNext(from now: Date) {
        let anchor = persistentState.nextScheduledDate ?? now
        persistentState.nextScheduledDate = calculator.nextAligned(
            after: anchor,
            now: now,
            interval: configuration.effectiveIntervalSeconds
        )
    }

    // MARK: - Status & persistence

    private var isRunningState: Bool {
        configuration.isEnabled && !persistentState.isPaused && !persistentState.pausedDueToFailures
    }

    private func recomputeStatus() {
        if !configuration.isEnabled {
            status = .stopped
        } else if persistentState.pausedDueToFailures {
            status = .error("Paused after repeated failures.")
        } else if persistentState.isPaused {
            status = .paused
        } else if permission.accessibilityStatus() != .granted {
            status = .permissionRequired
        } else {
            status = .running
        }
    }

    private func startTicker() {
        ticker.start(interval: tickInterval) { [weak self] in
            guard let self else { return }
            Task { await self.evaluate() }
        }
    }

    private func persist() {
        settingsStore.saveConfiguration(configuration)
        settingsStore.saveState(persistentState)
    }

    private func record(
        trigger: TriggerSource,
        success: Bool,
        result: AutomationResult?,
        error: AutomationError?,
        at timestamp: Date
    ) async {
        let digest = MessageDigest(message: configuration.message)
        let entry = LogEntry(
            timestamp: timestamp,
            trigger: trigger,
            success: success,
            messageCharacterCount: digest.characterCount,
            messageHashPrefix: digest.hashPrefix,
            messageWasEmpty: digest.isEmpty,
            didLaunchClaude: result?.didLaunchClaude ?? false,
            didOpenNewChat: result?.didOpenNewChat ?? false,
            didPaste: result?.didPaste ?? false,
            didSend: result?.didSend ?? false,
            duration: result?.duration ?? 0,
            errorDescription: error?.errorDescription
        )
        await logStore.append(entry, retentionCount: configuration.logRetentionCount)
    }
}
