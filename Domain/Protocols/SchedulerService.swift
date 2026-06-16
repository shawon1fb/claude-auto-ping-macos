import Foundation

/// Orchestrates the timed sending of messages. All access is main-actor bound
/// because it owns UI-facing state and timers.
@MainActor
public protocol SchedulerService: AnyObject {
    var status: SchedulerStatus { get }
    var configuration: SchedulerConfiguration { get }
    var persistentState: SchedulerPersistentState { get }

    /// Enables the scheduler and schedules the first execution.
    func start()
    /// Temporarily stops executions without clearing the schedule.
    func pause()
    /// Resumes after a pause, recomputing the next execution if needed.
    func resume()
    /// Disables the scheduler entirely and clears the next execution.
    func stop()

    /// Replaces the configuration, persisting it and rescheduling as needed.
    func updateConfiguration(_ configuration: SchedulerConfiguration)

    /// Runs the automation immediately as a manual test, bypassing the schedule
    /// but still honoring duplicate protection.
    func sendTestMessage() async
    /// Runs the automation without pressing Return, for verifying setup safely.
    func runDryTest() async

    /// Called when the Mac wakes; performs at most one catch-up send.
    func handleWake() async
}
