import Foundation

/// Drives periodic scheduler evaluations. Abstracted so production uses a real
/// `Timer` while tests inject a no-op ticker and evaluate deterministically.
@MainActor
public protocol SchedulerTicker: AnyObject {
    func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void)
    func stop()
}

/// Production ticker backed by a repeating main-runloop `Timer`.
@MainActor
public final class TimerSchedulerTicker: SchedulerTicker {
    private var timer: Timer?

    public init() {}

    public func start(interval: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        timer.tolerance = interval * 0.2
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
