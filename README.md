# Claude Auto Ping macOS

A transparent, user-controlled macOS menu bar utility that periodically opens the
Claude desktop app and sends a short, user-configured message (such as `hi`) on a
schedule you choose.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/License-MIT-green)

> **Trademark disclaimer:** This project is **not affiliated with, endorsed by, or
> sponsored by Anthropic**. "Claude" is a trademark of Anthropic. This is an
> independent, open-source utility that automates the local Claude desktop app's
> user interface only.

---

## What it does

Claude Auto Ping lives in your menu bar. On an interval you control, it brings the
Claude desktop app to the front, opens a new chat, pastes your configured message,
and (optionally) presses Return to send it. Everything happens locally through
standard macOS automation — there is no server, no account, and no network access.

### Why you might want this

Some people like a periodic, low-effort "ping" to keep a daily habit going. This
tool makes that explicit, visible, and entirely under your control — you start it,
you pause it, and you can uninstall it completely at any time.

## Features

- Menu bar app built with `MenuBarExtra` (SwiftUI), no Dock icon.
- Configurable message (default `hi`) with full Unicode and Bangla support.
- Interval presets: 30 min, 1, 2, 5, 8, 12, 24 hours, plus a custom interval.
- Minimum interval of 5 minutes, with a warning for short intervals.
- Start, pause, resume, stop, and "send test message now".
- Shows next scheduled run, last result, interval, and message at a glance.
- Wake-from-sleep recovery that sends **at most one** catch-up message.
- Five-minute duplicate-protection window to prevent accidental double sends.
- Auto-pause after three consecutive failures, to avoid uncontrolled retries.
- Launch at login via `SMAppService`.
- Privacy-preserving execution logs (no message content stored).
- Optional success/failure notifications.
- A separate, dependency-free standalone script + LaunchAgent version.

## Screenshots

Screenshots are placeholders until captured — see [docs/screenshots.md](docs/screenshots.md).

| Menu bar popover | Settings | Logs |
| --- | --- | --- |
| _placeholder_ | _placeholder_ | _placeholder_ |

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ (for building from source)
- [XcodeGen](https://github.com/yonsi/XcodeGen) (`brew install xcodegen`) — the
  `.xcodeproj` is generated from `project.yml`
- The Claude desktop app installed (for actual sending)

## Install (download)

1. Download the latest `ClaudeAutoPingMacos-vX.Y.Z.dmg` from the
   [Releases page](https://github.com/shawon1fb/claude-auto-ping-macos/releases/latest).
2. Open the DMG and drag **Claude Auto Ping** onto the **Applications** shortcut.
3. Launch it from Applications.

> **Unsigned build.** Release DMGs are not yet notarized, so macOS Gatekeeper
> blocks the first launch ("Apple could not verify…" or "is damaged"). Bypass it
> once, either way:
>
> - **Right-click** the app in Applications → **Open** → **Open**, or
> - clear the quarantine flag from Terminal:
>   ```bash
>   xattr -dr com.apple.quarantine /Applications/ClaudeAutoPingMacos.app
>   ```
>
> After the first launch macOS remembers the choice. The app is menu-bar only
> (no Dock icon) — look for its icon in the menu bar.

## Installation from source

```bash
git clone https://github.com/shawon1fb/claude-auto-ping-macos.git
cd claude-auto-ping-macos

# Generate the Xcode project from project.yml
xcodegen generate

# Build a Release .app into ./build
./Scripts/build-release.sh

# Then move build/ClaudeAutoPingMacos.app to /Applications and open it.
open build/ClaudeAutoPingMacos.app
```

Or open `ClaudeAutoPingMacos.xcodeproj` in Xcode and run the `ClaudeAutoPingMacos`
scheme.

## Standalone script installation

If you prefer not to build the app, use the standalone AppleScript + LaunchAgent:

```bash
cd claude-auto-ping-macos/Scripts

# Interactive install (prompts for interval/message), or pass flags:
./install-launch-agent.sh --interval 18000 --message "hi"

# Verify automation without sending (no Return pressed):
./test-automation.sh

# Remove everything (keeps exported logs):
./uninstall-launch-agent.sh
```

The installer runs entirely in user space (no `sudo`), installs files under
`~/Library/Application Support/ClaudeAutoPingMacos`, registers a user LaunchAgent
in `~/Library/LaunchAgents`, validates the plist with `plutil`, and loads it with
`launchctl bootstrap`. See [Scripts/](Scripts/) and
[docs/permissions.md](docs/permissions.md).

## Permission setup

macOS UI automation requires two permissions. Grant them once:

1. **Accessibility** — System Settings → Privacy & Security → Accessibility →
   enable Claude Auto Ping (or the program running the standalone script).
2. **Automation** — System Settings → Privacy & Security → Automation → allow
   control of **System Events** and **Claude**.

The app never prompts in a loop. Use the buttons in **Settings → Permissions** to
open the right panes, then return to the app. Full details:
[docs/permissions.md](docs/permissions.md).

## Usage

1. Open the app; its icon appears in the menu bar.
2. Open **Settings → General** and set your message and interval.
3. Open **Settings → Permissions**:
   - **Open Accessibility settings** → enable Claude Auto Ping. The checklist
     turns green on its own within a couple of seconds (it re-checks on app
     activation and while the tab is visible — no relaunch needed).
   - **Trigger Automation prompt (dry-run)** → this runs a no-send dry-run that
     makes macOS show the one-time Automation consent dialog and adds the app to
     the Automation list. Approve **System Events** and **Claude**.
4. Back on **General/Automation**, click **Send Test Message** to confirm it
   works.
5. Click **Start Scheduler**.

The menu bar icon reflects the state: running, paused, error, or permission
required.

> **Why the Automation step needs a dry-run:** macOS does not let an app be
> pre-added to the Automation list. An app only appears there *after* it first
> tries to control another app, which is exactly what the dry-run does.

## Architecture summary

The codebase separates pure domain logic from SwiftUI and system APIs:

- **Domain** — value models (`SchedulerConfiguration`, `LogEntry`, …) and
  protocols (`SchedulerService`, `AutomationService`, `SettingsStore`, …).
- **Infrastructure** — concrete services: scheduling, Claude automation,
  persistence, permissions, system integration.
- **Features** — SwiftUI views and view models for the menu bar, settings, logs.
- **App** — the composition root (`AppEnvironment`) wires dependencies together.

Scheduling math lives in a pure, fully unit-tested `ScheduleCalculator`. Time and
periodic ticks are injected, so the scheduler is deterministic in tests. More:
[docs/architecture.md](docs/architecture.md).

## Troubleshooting

Common issues (Claude not found, nothing pastes, permission revoked, UI changes)
are covered in [docs/troubleshooting.md](docs/troubleshooting.md).

## Reset to a clean state (cold start)

To return the app to a clean first-run state — quit it, reset its macOS privacy
permissions (Accessibility, Automation, Notifications), and clear its saved
settings, state, and logs:

```bash
./Scripts/cold-start-reset.sh
# then reopen the app
open build/ClaudeAutoPingMacos.app
```

This runs in user space (no `sudo`) and does not delete the app bundle. It is
handy after rebuilding or when permissions get into a confusing state.

## Uninstallation

`./Scripts/uninstall-launch-agent.sh` is a complete uninstaller. It quits the
app, removes the standalone LaunchAgent and its script, **resets the app's macOS
privacy permissions** (the TCC "permission cache" — Accessibility, Automation,
Notifications), and clears saved settings. It runs in user space and never
touches unrelated files.

```bash
./Scripts/uninstall-launch-agent.sh                 # full uninstall, keeps logs
./Scripts/uninstall-launch-agent.sh --remove-logs   # also delete logs
./Scripts/uninstall-launch-agent.sh --keep-permissions   # leave TCC grants
./Scripts/uninstall-launch-agent.sh --remove-app /Applications/ClaudeAutoPingMacos.app
```

- **App-only quick cleanup:** Settings → Advanced → "Uninstall background
  components" stops the scheduler and removes the login item. For a full
  privacy/state wipe (including permissions), run the script above.
- **Just reset, not uninstall:** `./Scripts/cold-start-reset.sh` returns the app
  to a clean first-run state without removing the LaunchAgent.

## Building a release

`./Scripts/build-release.sh` produces an **ad-hoc signed** `.app` by default.

### Stable signing (recommended for development)

macOS keys Accessibility/Automation grants to the app's **code signature**, so an
ad-hoc build gets a new identity on every rebuild and must be re-granted. Sign
with a stable identity to keep grants across rebuilds:

```bash
# List available signing identities
security find-identity -v -p codesigning

# Build signed with a stable identity (Apple Development or Developer ID)
CODESIGN_IDENTITY="Apple Development: You (TEAMID)" ./Scripts/build-release.sh
```

Adding Developer ID signing and notarization for distribution is documented in
[docs/release-process.md](docs/release-process.md). Permission details:
[docs/permissions.md](docs/permissions.md).

## App icon

The icon is generated programmatically (no external tools) and can be
regenerated after tweaking color or glyph:

```bash
swift Scripts/generate-app-icon.swift
```

It writes every size into `Resources/Assets.xcassets/AppIcon.appiconset` and
updates `Contents.json`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: fork, branch, keep domain logic
testable, run `xcodegen generate` and the test suite, and open a PR.

## Security reporting

Please do not file security issues publicly or include credentials in issues. See
[SECURITY.md](SECURITY.md).

## Privacy

Claude Auto Ping is built to be privacy-friendly:

- **Fully local** — no servers, no accounts, no network access required.
- **No telemetry or analytics** of any kind.
- **No message history** — logs store only a character count, an optional short
  hash, and an emptiness flag, never the message text.
- **No reading** of Claude conversations, responses, cookies, or credentials.
- It does **not** attempt to bypass Claude usage limits, automate login/CAPTCHA,
  or hide its behavior.

## Known limitations

- UI automation depends on Claude's current keyboard shortcuts and layout; a
  Claude update can break it until the shortcut/delays are adjusted.
- The clipboard is restored after each send, but only the first pasteboard item's
  representations are captured; unusual multi-item clipboards may not fully
  restore.
- Automation cannot run while the Mac is locked; runs are skipped and retried at
  the next interval.
- Distributed outside the Mac App Store because Accessibility/Automation are
  incompatible with App Store sandboxing.

## License

MIT — see [LICENSE](LICENSE).
