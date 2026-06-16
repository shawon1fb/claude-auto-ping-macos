# Architecture

Claude Auto Ping is layered to keep pure domain logic independent from SwiftUI and
system frameworks, following SOLID principles and dependency injection.

## Layers

```
App/             Composition root + SwiftUI app entry
Features/        SwiftUI views and view models (MenuBar, Settings, Logs)
Domain/          Value models + service protocols (no UIKit/AppKit/SwiftUI)
Infrastructure/  Concrete implementations of the protocols
```

### Domain

- **Models** are plain `Codable`/`Sendable` value types:
  `SchedulerConfiguration`, `SchedulerPersistentState`, `SchedulerStatus`,
  `AutomationConfiguration`, `AutomationResult`, `LogEntry`, `AutomationError`,
  `KeyboardShortcut`, `IntervalPreset`.
- **Protocols** define every important service: `SchedulerService`,
  `AutomationService`, `ClaudeAppController`, `ClaudeAppLocator`,
  `AppleScriptRunner`, `ClipboardManager`, `SettingsStore`, `LogStore`,
  `PermissionService`, `LaunchAtLoginService`, `NotificationService`,
  `SystemStateProvider`, and `Clock`.

### Infrastructure

- **Scheduling** — `ScheduleCalculator` (pure math), `DefaultSchedulerService`
  (orchestration), `WakeObserver`, `SchedulerTicker`.
- **Automation** — `ClaudeAutomationService` (steps), `DefaultClaudeAppController`
  (launch/activate/readiness via `NSWorkspace`), `NSAppleScriptRunner`,
  `DefaultClipboardManager`, `DefaultClaudeAppLocator`.
- **Persistence** — `UserDefaultsSettingsStore`, `FileLogStore` (an `actor`),
  `MessageDigest` (privacy-safe metadata).
- **Permissions / System** — `AccessibilityPermissionService`,
  `DefaultLaunchAtLoginService`, `DefaultSystemStateProvider`, `AppInfo`.
- **Notifications** — `UserNotificationService`.

### App

`AppEnvironment` is the single composition root. It is the only place that
constructs concrete services and wires them into `DefaultSchedulerService`. Views
receive `AppEnvironment` and call high-level actions; they contain no business
logic.

## Key design decisions

### Deterministic scheduling

All time comes from an injected `Clock`, and all periodic evaluation comes from an
injected `SchedulerTicker`. Tests use a `MockClock` and a `MockSchedulerTicker`
that fires on demand, so scheduler behavior is fully deterministic with no real
timers or wall-clock dependence.

`ScheduleCalculator` is pure and side-effect free. `nextAligned(after:now:interval:)`
always returns a single future slot aligned to the original cadence, which avoids
both drift (recomputing from `now`) and stacking (a backlog of missed sends).

### At-most-once catch-up

After sleep/logout/relaunch, `resolveMissed` decides whether a single catch-up
send is due and computes the next future slot. The scheduler sends at most one
message and never queues missed ones. A duplicate-protection cooldown
(default 5 minutes) blocks re-sends triggered by relaunch, double timers, or wake.

### Safe automation

The configured message is never interpolated into AppleScript. It is delivered via
the clipboard: snapshot → set string → Command+V → restore (in a `defer`, so the
clipboard is restored on success and failure alike). App launch/activation is
behind `ClaudeAppController`, so the keystroke/clipboard logic is unit-testable
without a real Claude window.

### Failure safety

Three consecutive automatic failures auto-pause the scheduler and notify the user,
preventing uncontrolled repeated actions. Manual tests and dry runs report errors
but do not count toward the auto-pause limit.

## Testing strategy

- `ScheduleCalculatorTests` — first/next/missed math, DST immunity, clock changes,
  cooldown.
- `SchedulerServiceTests` — start/pause/resume/stop, manual/automatic execution,
  failure recovery, wake recovery, duplicate protection, permission and lock
  handling, settings updates — all with mocks.
- `SettingsStoreTests` — defaults, round-trip, invalid data fallback, migration.
- `ClaudeAutomationServiceTests` — paste/send, clipboard restoration on success
  and failure, error mapping, Unicode/Bangla.
