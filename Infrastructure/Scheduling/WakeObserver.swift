import Foundation
import AppKit

/// Observes system wake notifications and invokes a handler so the scheduler can
/// perform at most one catch-up send after the Mac wakes from sleep.
@MainActor
public final class WakeObserver {
    private var observers: [NSObjectProtocol] = []
    private let center = NSWorkspace.shared.notificationCenter

    public init() {}

    /// Begins observing wake notifications. The handler runs on the main actor.
    public func start(onWake: @escaping @MainActor () -> Void) {
        stop()
        let names: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    onWake()
                }
            }
            observers.append(token)
        }
    }

    public func stop() {
        for token in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
    }
}
