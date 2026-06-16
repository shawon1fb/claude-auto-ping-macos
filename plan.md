# Project: Open-Source macOS Claude Message Scheduler

Act as a senior macOS engineer, Swift architect, automation engineer, UI/UX designer, QA engineer, and open-source maintainer.

Build a complete, production-quality, open-source macOS utility that periodically opens the Claude desktop app and sends a user-configured message such as `hi`.

The application must be transparent, user-controlled, privacy-friendly, easy to install, and easy to uninstall.

Do not only provide a plan. Create the complete working project, source files, scripts, tests, documentation, and GitHub configuration.

---

# 1. Project Overview

Create a macOS menu bar application with the working name:

**Claude Auto Ping macOS**

Suggested GitHub repository name:

```text
claude-auto-ping-macos
```

The app should allow a user to:

* Select a repeat interval, with a default of every 5 hours
* Configure the message to send, with a default value of `hi`
* Start, pause, resume, and stop the scheduler
* Send a test message immediately
* See the next scheduled execution time
* See the last execution time and result
* Enable or disable sending after the Mac wakes from sleep
* Enable or disable launching at login
* View recent execution logs
* Open the required macOS permission settings
* Completely uninstall the helper and scheduled job

The utility must perform local UI automation only.

It must not:

* Collect credentials
* Read Claude conversations
* Scrape Claude content
* Access browser cookies
* Send analytics
* Include tracking
* Contact any custom backend
* Hide its behavior from the user
* Attempt to bypass Claude usage limits
* Automate login or CAPTCHA flows

Add a visible disclaimer that the project is not affiliated with, endorsed by, or sponsored by Anthropic.

---

# 2. Platform and Technology

Use:

* Swift 6
* SwiftUI
* AppKit where required
* macOS 14 or later
* Xcode project
* Native Apple frameworks only
* No third-party dependencies unless absolutely necessary
* XCTest for unit tests
* OSLog for structured logs
* SMAppService for launch-at-login support
* Accessibility APIs, Apple Events, or AppleScript for Claude UI automation
* NSWorkspace notifications for sleep and wake handling
* UserDefaults or a small Codable settings store for preferences

Do not use Electron.

Do not require a server.

Do not require a Claude API key.

Do not use private macOS APIs.

The app will be distributed as an open-source utility outside the Mac App Store because Accessibility and UI scripting permissions may not be compatible with normal App Store sandbox restrictions.

Clearly document signing and sandbox implications.

---

# 3. Product Architecture

Use a clean, testable architecture based on SOLID principles.

Create protocols for all important services.

Suggested structure:

```text
ClaudeAutoPingMacos/
├── ClaudeAutoPingMacos.xcodeproj
├── App/
│   ├── ClaudeAutoPingMacosApp.swift
│   ├── AppDelegate.swift
│   └── AppEnvironment.swift
│
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift
│   │   ├── MenuBarViewModel.swift
│   │   └── SchedulerStatusView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsView.swift
│   │   ├── AutomationSettingsView.swift
│   │   └── PermissionSettingsView.swift
│   │
│   └── Logs/
│       ├── LogsView.swift
│       └── LogsViewModel.swift
│
├── Domain/
│   ├── Models/
│   │   ├── SchedulerConfiguration.swift
│   │   ├── SchedulerState.swift
│   │   ├── AutomationResult.swift
│   │   └── LogEntry.swift
│   │
│   └── Protocols/
│       ├── SchedulerService.swift
│       ├── AutomationService.swift
│       ├── SettingsStore.swift
│       ├── PermissionService.swift
│       ├── LogStore.swift
│       └── LaunchAtLoginService.swift
│
├── Infrastructure/
│   ├── Scheduling/
│   │   ├── DefaultSchedulerService.swift
│   │   ├── ScheduleCalculator.swift
│   │   └── WakeObserver.swift
│   │
│   ├── Automation/
│   │   ├── ClaudeAutomationService.swift
│   │   ├── AppleScriptRunner.swift
│   │   ├── ClaudeAppLocator.swift
│   │   ├── ClipboardManager.swift
│   │   └── AutomationError.swift
│   │
│   ├── Persistence/
│   │   ├── UserDefaultsSettingsStore.swift
│   │   └── FileLogStore.swift
│   │
│   ├── Permissions/
│   │   └── AccessibilityPermissionService.swift
│   │
│   └── System/
│       └── DefaultLaunchAtLoginService.swift
│
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
│
├── Scripts/
│   ├── claude-auto-ping.applescript
│   ├── install-launch-agent.sh
│   ├── uninstall-launch-agent.sh
│   ├── test-automation.sh
│   └── build-release.sh
│
├── LaunchAgent/
│   └── com.opensource.claudeautopingmacos.plist.template
│
├── Tests/
│   ├── ScheduleCalculatorTests.swift
│   ├── SchedulerServiceTests.swift
│   ├── SettingsStoreTests.swift
│   └── ClaudeAutomationServiceTests.swift
│
├── docs/
│   ├── architecture.md
│   ├── permissions.md
│   ├── troubleshooting.md
│   ├── release-process.md
│   └── screenshots.md
│
├── .github/
│   ├── workflows/
│   │   ├── build.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   └── pull_request_template.md
│
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── CHANGELOG.md
└── .gitignore
```

You may improve this architecture where appropriate, but keep the domain logic independent from SwiftUI and system APIs.

---

# 4. Core Scheduling Requirements

Create a reliable scheduler with these behaviors:

## Default behavior

* Default interval: 5 hours
* Default message: `hi`
* Default action: open a new Claude chat, paste the message, and send it
* Scheduler must be disabled until the user explicitly starts it

## Supported intervals

Provide presets:

* 30 minutes
* 1 hour
* 2 hours
* 5 hours
* 8 hours
* 12 hours
* 24 hours
* Custom interval

Custom interval must support hours and minutes.

Minimum allowed interval:

```text
5 minutes
```

Show a warning for unusually short intervals.

## Scheduler state

Persist:

* Whether the scheduler is enabled
* Selected interval
* Message
* Last scheduled execution
* Last successful execution
* Last failure
* Next scheduled execution
* Whether wake recovery is enabled
* Whether launch at login is enabled

## Missed execution handling

When the Mac sleeps or the user logs out:

* Do not queue and send multiple missed messages
* When the Mac wakes, calculate whether an execution was missed
* When wake recovery is enabled, send at most one message
* Apply a cooldown to prevent duplicate messages
* Recalculate the next scheduled date after execution

The schedule calculation must be implemented as pure testable domain logic.

## Duplicate protection

Add a default five-minute duplicate prevention window.

A message must not be sent twice due to:

* App relaunch
* Multiple timers
* Wake notifications
* Settings changes
* Launch-at-login execution

---

# 5. Claude Automation Requirements

Create an `AutomationService` protocol.

Example:

```swift
protocol AutomationService {
    func sendMessage(
        _ message: String,
        configuration: AutomationConfiguration
    ) async throws -> AutomationResult
}
```

The implementation must:

1. Locate the Claude desktop app
2. Launch Claude if it is not running
3. Bring Claude to the foreground
4. Wait for the app to become ready
5. Open a new conversation
6. Paste the configured message
7. Optionally press Return to send
8. Return a structured success or failure result

## Claude app discovery

Do not rely only on the application display name.

Attempt to locate Claude through:

* Known bundle identifiers when available
* NSWorkspace running applications
* `/Applications`
* `~/Applications`
* User-selected app location as a fallback

Do not invent or blindly hardcode a bundle identifier without verification.

Allow the user to select the Claude application manually when automatic discovery fails.

## UI automation strategy

Use a layered approach:

1. Prefer Accessibility APIs where reliable
2. Use AppleScript/System Events as a practical fallback
3. Keep automation implementation isolated behind the protocol
4. Make delays configurable
5. Return clear errors when UI automation fails

Default workflow:

```text
Activate Claude
Wait until foreground
Press Command+N
Wait for the new chat
Paste message
Wait briefly
Press Return
```

Make these configurable:

* New-chat keyboard shortcut
* Delay after launch
* Delay after opening a new chat
* Delay before pressing Return
* Whether Return should be pressed automatically

## Safe text insertion

Do not directly interpolate unescaped user input into executable AppleScript.

Preferred approach:

* Temporarily save the current clipboard
* Put the configured message on the clipboard
* Paste using Command+V
* Restore the previous clipboard after completion

Handle clipboard restoration even when an error occurs.

Document any clipboard limitations.

Support Unicode and Bangla messages.

## Permission handling

The app must clearly detect or explain:

* Accessibility permission
* Automation permission for controlling System Events
* Permission to control the Claude app where applicable

Provide buttons for:

* Check permissions
* Open Accessibility Settings
* Open Automation Settings when possible
* Run a permission test
* Run a dry test without pressing Return

Never repeatedly prompt the user in a loop.

---

# 6. Menu Bar UI

Create a native macOS menu bar app using `MenuBarExtra`.

The menu bar icon should visually communicate:

* Running
* Paused
* Error
* Permission required

Use SF Symbols.

Suggested symbols:

* Running: `paperplane.circle.fill`
* Paused: `pause.circle`
* Error: `exclamationmark.triangle`
* Permission required: `lock.trianglebadge.exclamationmark`

The menu bar popover should show:

```text
Claude Auto Ping macOS

Status: Running
Next message: Today, 8:30 PM
Interval: Every 5 hours
Message: hi

[Send Test Message]
[Pause Scheduler]

Recent result:
Successfully sent at 3:30 PM

[Settings]
[View Logs]
[Quit]
```

Follow Apple Human Interface Guidelines.

Use:

* Native controls
* Clear spacing
* Accessible labels
* Keyboard navigation
* VoiceOver support
* Light and dark mode
* No custom gradients
* No oversized cards
* No unnecessary animations

---

# 7. Settings UI

Create a normal macOS Settings window with these sections.

## General

* Message input
* Interval preset
* Custom interval
* Launch at login
* Start scheduler automatically after launch
* Run once after waking when overdue
* Show notification after successful send
* Show notification after failure

## Automation

* Claude application path
* Detect Claude button
* Choose Claude app button
* New-chat shortcut configuration
* Launch delay
* New-chat delay
* Send delay
* Automatically press Return
* Dry-run test
* Full send test

## Permissions

Show a checklist:

* Claude app found
* Accessibility permission granted
* Automation permission available
* Launch-at-login status

Each item should have a concise explanation and a relevant action button.

## Advanced

* Duplicate prevention cooldown
* Log retention count
* Reset configuration
* Export logs
* Open logs directory
* Uninstall background components

---

# 8. Logging and Diagnostics

Use OSLog for system logs and maintain a small user-readable log store.

Each execution log should contain:

* Timestamp
* Trigger source
* Scheduled execution or manual test
* Claude launch result
* New-chat result
* Paste result
* Send result
* Total duration
* Error message when applicable

Do not log the complete configured message by default.

Instead log:

* Message character count
* A SHA-256 hash if useful
* Whether the message was empty

Keep the latest 100 log records by default.

Allow the user to:

* View logs
* Copy selected log
* Export logs as JSON
* Clear logs

Do not include private conversation content in logs.

---

# 9. Notifications

Use native macOS notifications.

Provide optional notifications for:

* Successful message send
* Failed message send
* Scheduler paused due to repeated failures
* Permission missing

After three consecutive automation failures:

* Pause automatic sending
* Show an error state
* Notify the user
* Require a manual test or explicit resume

This prevents uncontrolled repeated actions.

---

# 10. Standalone Script Version

In addition to the SwiftUI app, provide a minimal standalone implementation for users who do not want to build the app.

Include:

```text
Scripts/claude-auto-ping.applescript
Scripts/install-launch-agent.sh
Scripts/uninstall-launch-agent.sh
Scripts/test-automation.sh
LaunchAgent/com.opensource.claudeautopingmacos.plist.template
```

The installer must:

* Ask for or accept an interval
* Default to 18,000 seconds
* Ask for or accept a message
* Install scripts under a user-specific application support directory
* Install a user LaunchAgent under `~/Library/LaunchAgents`
* Validate the plist using `plutil`
* Load the agent using modern `launchctl bootstrap`
* Print clear permission instructions
* Avoid requiring root access
* Back up an existing configuration before replacing it

The uninstaller must:

* Stop the LaunchAgent
* Remove installed files
* Preserve exported logs unless the user chooses to remove them
* Never delete unrelated files

Shell scripts must use:

```bash
set -euo pipefail
```

Quote all paths correctly.

Support paths containing spaces.

Run ShellCheck-compatible code where possible.

---

# 11. Testing Requirements

Write meaningful unit tests.

At minimum test:

## Schedule calculator

* First scheduled execution
* Repeating five-hour interval
* Custom interval
* Missed execution after sleep
* No duplicate catch-up executions
* Cooldown behavior
* Daylight-saving transitions
* App relaunch
* Invalid interval
* Clock moving backward
* Clock moving forward

## Scheduler service

Use a mocked clock and mocked automation service.

Test:

* Start
* Pause
* Resume
* Manual execution
* Automatic execution
* Failure recovery
* Pause after three failures
* Settings updates
* Wake recovery
* Duplicate prevention

## Settings

Test:

* Default settings
* Encoding and decoding
* Invalid stored data fallback
* Migration from older settings versions

## Automation

Do not require Claude to be installed for unit tests.

Use:

* Mock application locator
* Mock AppleScript runner
* Mock clipboard service
* Mock permission service

Verify that the clipboard is restored after both success and failure.

---

# 12. Accessibility and Privacy

Add accessibility labels and help text to all buttons and status indicators.

The application must be usable with:

* VoiceOver
* Keyboard navigation
* Increased contrast
* Reduced motion
* Light mode
* Dark mode

Privacy principles:

* Fully local processing
* No accounts
* No telemetry
* No analytics
* No network access required
* No message history collection
* No reading of Claude responses

Add a Privacy section to the README.

---

# 13. Open-Source Repository Requirements

Use the MIT License.

Create:

## README.md

Include:

* Project overview
* Screenshot placeholders
* Features
* Requirements
* Installation from source
* Standalone script installation
* Permission setup
* Usage
* Architecture summary
* Troubleshooting
* Uninstallation
* Building a release
* Contributing
* Security reporting
* Trademark disclaimer
* Privacy statement
* Known limitations

Add badges for:

* macOS
* Swift
* License
* Build status

Do not add fake release or coverage badges.

## CONTRIBUTING.md

Include:

* Development setup
* Branch naming
* Commit style
* Pull request requirements
* Testing requirements
* Code style
* How to report UI breakage after a Claude update

## SECURITY.md

Clearly state:

* No credentials should be submitted in issues
* How to privately report vulnerabilities
* Supported versions
* UI automation risks
* Clipboard behavior

Use a placeholder security email clearly marked for replacement.

## CODE_OF_CONDUCT.md

Use Contributor Covenant language or an equivalent standard open-source code of conduct.

## CHANGELOG.md

Follow Keep a Changelog format.

Start with:

```text
[Unreleased]
[0.1.0]
```

## GitHub issue templates

Create:

* Bug report
* Feature request

Bug reports should ask for:

* macOS version
* Claude app version
* App version
* Permission status
* Relevant sanitized logs
* Whether the Claude UI recently changed

---

# 14. GitHub Actions

Create a build workflow that:

* Runs on `macos-latest`
* Checks out the repository
* Prints Swift and Xcode versions
* Builds the app in Debug configuration
* Runs unit tests
* Validates plist files
* Checks shell script syntax
* Does not require signing secrets for pull requests

Example validation commands may include:

```bash
xcodebuild \
  -project ClaudeAutoPingMacos.xcodeproj \
  -scheme ClaudeAutoPingMacos \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project ClaudeAutoPingMacos.xcodeproj \
  -scheme ClaudeAutoPingMacos \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test

plutil -lint LaunchAgent/*.plist.template
bash -n Scripts/*.sh
```

Adjust commands to match the final project.

Create a release workflow template for tagged releases.

Do not require real signing credentials in the initial implementation.

Document how a maintainer can later add:

* Developer ID Application signing
* Notarization
* GitHub release assets

---

# 15. Error Handling

Create user-friendly typed errors for:

* Claude not installed
* Claude failed to launch
* Accessibility permission denied
* Automation permission denied
* Claude process not found
* New-chat shortcut failed
* Clipboard write failed
* Paste failed
* Send failed
* Scheduler configuration invalid
* Duplicate execution blocked
* Automation timed out

Errors shown in the UI must provide a suggested recovery action.

Do not expose raw internal stack traces in normal UI.

Preserve technical details in diagnostic logs.

---

# 16. Important Edge Cases

Handle these cases:

* Claude is already open
* Claude is closed
* Claude is updating
* Claude opens slowly
* Claude is installed in `~/Applications`
* Multiple Claude-like apps exist
* The user changes Spaces
* The Mac is locked
* The Mac is sleeping
* The user is logged out
* The clipboard contains rich data
* The configured message contains Bangla or emoji
* The message is empty
* Accessibility permission is revoked
* Claude changes its keyboard shortcut
* Claude changes its UI
* A timer fires twice
* The system clock changes
* The app crashes and relaunches
* Launch at login is disabled externally

When the Mac is locked, do not repeatedly attempt UI automation.

Record a clear failure and wait until the next valid opportunity.

---

# 17. Implementation Rules

Follow these rules strictly:

* No pseudocode in production files
* No empty placeholder types
* No unfinished TODO implementations
* No force unwraps unless technically unavoidable and justified
* No silent error swallowing
* No massive view files
* No business logic inside SwiftUI views
* No singleton-heavy architecture
* Use dependency injection
* Use async/await where appropriate
* Mark UI-bound code with `@MainActor`
* Make time and clock behavior injectable for tests
* Format code consistently
* Add documentation comments to public protocols and important types
* Keep functions small and focused
* Ensure all scripts are executable
* Ensure all generated paths match the actual repository
* Ensure README commands work

---

# 18. Development Sequence

Execute the work in this order:

1. Inspect the current directory and existing files
2. Create the repository structure
3. Create the Xcode project
4. Implement domain models and protocols
5. Implement schedule calculation
6. Implement settings persistence
7. Implement Claude app discovery
8. Implement permission handling
9. Implement clipboard-safe automation
10. Implement scheduler orchestration
11. Implement sleep and wake recovery
12. Implement menu bar UI
13. Implement Settings UI
14. Implement logs and notifications
15. Implement standalone AppleScript and LaunchAgent scripts
16. Add tests
17. Add documentation
18. Add GitHub Actions
19. Run build and tests
20. Fix all build errors and test failures
21. Validate shell scripts and plist files
22. Provide a final implementation report

Do not stop after scaffolding.

---

# 19. Validation Before Completion

Before declaring completion, run all appropriate checks available in the environment.

At minimum:

```bash
xcodebuild \
  -project ClaudeAutoPingMacos.xcodeproj \
  -scheme ClaudeAutoPingMacos \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests:

```bash
xcodebuild \
  -project ClaudeAutoPingMacos.xcodeproj \
  -scheme ClaudeAutoPingMacos \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Validate scripts:

```bash
bash -n Scripts/*.sh
```

Validate plist files:

```bash
plutil -lint LaunchAgent/*.plist.template
```

Search for unfinished work:

```bash
grep -R "TODO\|FIXME\|fatalError(\"Not implemented" . \
  --exclude-dir=.git \
  --exclude-dir=DerivedData
```

Fix any meaningful result before finishing.

If Xcode is unavailable, still create the complete project and clearly state which validation could not be run.

---

# 20. Final Response Format

At the end, provide:

1. A concise summary of what was implemented
2. Final repository tree
3. Important architecture decisions
4. Build and test results
5. Exact commands to run the project
6. Exact commands to install the standalone version
7. Permission setup steps
8. Known limitations
9. Recommended next improvements
10. Any files that require maintainer customization

Do not claim that a command succeeded unless it was actually executed successfully.

The final result must be suitable for publishing as an initial `v0.1.0` open-source GitHub repository.
