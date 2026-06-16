# Contributing to Claude Auto Ping macOS

Thanks for your interest in contributing. This project aims to be a small,
transparent, well-tested macOS utility. Contributions that keep it that way are
very welcome.

## Development setup

```bash
brew install xcodegen
git clone https://github.com/<your-org>/claude-auto-ping-macos.git
cd claude-auto-ping-macos
xcodegen generate
open ClaudeAutoPingMacos.xcodeproj
```

The `.xcodeproj` is generated from `project.yml` and is git-ignored. Always run
`xcodegen generate` after pulling changes that touch the project structure.

## Building and testing

```bash
# Build
xcodebuild -project ClaudeAutoPingMacos.xcodeproj -scheme ClaudeAutoPingMacos \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

# Test
xcodebuild -project ClaudeAutoPingMacos.xcodeproj -scheme ClaudeAutoPingMacos \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

# Validate scripts and plist
shellcheck Scripts/*.sh
bash -n Scripts/*.sh
plutil -lint LaunchAgent/*.plist.template
```

## Branch naming

- `feature/<short-description>`
- `fix/<short-description>`
- `docs/<short-description>`
- `chore/<short-description>`

## Commit style

Use clear, imperative commit messages, ideally
[Conventional Commits](https://www.conventionalcommits.org/):

```
feat(scheduler): add custom interval validation
fix(automation): preserve clipboard on paste failure
docs(readme): clarify permission steps
```

## Pull request requirements

- The build and the full test suite pass.
- New behavior in domain logic has unit tests (mock the clock and services;
  never require Claude to be installed for unit tests).
- No business logic added inside SwiftUI views.
- No force unwraps without a clear, justified reason.
- No silent error swallowing — surface a typed error or log it.
- Public protocols and important types have documentation comments.
- Shell scripts remain ShellCheck-clean.

## Testing requirements

- Pure scheduling logic belongs in `ScheduleCalculator` with table-style tests.
- Scheduler behavior is tested via `DefaultSchedulerService` using the mock clock,
  mock ticker, and mock services in `Tests/Mocks.swift`.
- Automation is tested via `ClaudeAutomationService` with a mock app controller,
  AppleScript runner, and clipboard — including clipboard restoration on failure.

## Code style

- Swift 6, strict concurrency. Mark UI-bound types `@MainActor`.
- Prefer `async/await`; inject time and side effects for testability.
- Keep functions small and focused; avoid massive view files.
- Match the existing formatting and naming.

## Reporting UI breakage after a Claude update

Claude UI changes can break automation. When that happens:

1. Open a **Bug report** issue and note the Claude app version.
2. Describe what changed (for example, the new-chat shortcut or window behavior).
3. Include sanitized logs (Settings → Logs → Copy selected; they contain no
   message content).
4. If you found a working shortcut/delay, include it — that often is the fix.

By contributing, you agree your contributions are licensed under the project's
[MIT License](LICENSE).
