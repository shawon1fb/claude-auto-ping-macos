# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet.

## [0.1.0] - 2026-06-16

### Added
- Menu bar app (`MenuBarExtra`) with running / paused / error / permission states.
- Configurable message (default `hi`) with Unicode and Bangla support.
- Interval presets (30 min, 1, 2, 5, 8, 12, 24 hours) and a custom interval, with
  a 5-minute minimum and a short-interval warning.
- Start, pause, resume, stop, send-test-message, and dry-run actions.
- Pure, unit-tested `ScheduleCalculator` for first/next/missed scheduling.
- Wake-from-sleep recovery sending at most one catch-up message.
- Five-minute duplicate-protection cooldown.
- Auto-pause after three consecutive failures.
- Clipboard-safe automation that restores the previous clipboard on success and
  failure.
- Layered Claude app discovery (preferred path, running apps, `/Applications`,
  `~/Applications`, manual selection).
- Accessibility/Automation permission checks and deep links.
- Launch at login via `SMAppService`.
- Privacy-preserving file-backed execution logs (no message content stored).
- Optional success/failure notifications.
- Settings UI: General, Automation, Permissions, Advanced, and Logs.
- Standalone AppleScript + LaunchAgent with install/uninstall/test scripts.
- Unit tests for the calculator, scheduler, settings store, and automation.
- GitHub Actions build workflow and a tagged-release workflow template.

[Unreleased]: https://github.com/<your-org>/claude-auto-ping-macos/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/<your-org>/claude-auto-ping-macos/releases/tag/v0.1.0
