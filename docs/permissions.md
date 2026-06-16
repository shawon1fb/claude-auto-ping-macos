# Permissions

macOS requires explicit permission for one app to control another. Claude Auto
Ping needs two permissions, granted once.

## 1. Accessibility

Used to post the keystrokes that open a new chat, paste, and press Return.

- System Settings → Privacy & Security → **Accessibility**
- Enable the toggle for **Claude Auto Ping** (app build), or for the program
  running the standalone script (for example, the terminal you ran it from, or
  `osascript`).

The app checks this with `AXIsProcessTrusted()` and shows status in
**Settings → Permissions**. It will request the system prompt **once** when you
press "Request Accessibility prompt"; it never loops.

## 2. Automation

Used to send Apple Events to **System Events** (and to Claude).

- System Settings → Privacy & Security → **Automation**
- Under Claude Auto Ping (or your terminal), allow control of **System Events**
  and **Claude**.

The first time automation runs, macOS shows a one-time consent dialog per target
app. If you deny it, the app reports `automationPermissionDenied` with a recovery
hint and a button to open the Automation pane.

## Why no App Sandbox?

App Sandbox is incompatible with controlling another application's UI. This app is
therefore distributed **outside the Mac App Store** and ships without the sandbox
entitlement. It does enable the hardened runtime and the
`com.apple.security.automation.apple-events` entitlement. See
`App/ClaudeAutoPingMacos.entitlements`.

## "I enabled the toggle but the app still shows red"

macOS keys Accessibility/Automation grants to the app's **code signature**, not
its path. Two consequences:

- **The app re-checks automatically.** When you grant access in System Settings
  and switch back, the Permissions tab updates within a couple of seconds (it
  also re-checks on activation). No relaunch is needed for a matching build.
- **Ad-hoc/unsigned rebuilds change identity.** The default `build-release.sh`
  output is ad-hoc signed, so **every rebuild is a new identity**. A grant made
  to a previous build does not apply, even though a stale `ClaudeAutoPingMacos`
  entry may still appear toggled on. Remove the stale entry (select it, click
  **–**), then add the current app again.

### Make grants persist across rebuilds

Sign with a **stable identity** so the code signature — and therefore the grant —
stays the same between builds:

```bash
# A real "Apple Development" cert (from Xcode) or a Developer ID both work:
CODESIGN_IDENTITY="Apple Development: You (TEAMID)" ./Scripts/build-release.sh

# List available identities:
security find-identity -v -p codesigning
```

After the first grant to a stably-signed build, subsequent rebuilds keep the
permission.

## Revoked permissions

If you later revoke Accessibility, scheduled runs fail safely: the app records a
clear error, surfaces the "permission required" state, and does not retry in a
loop. Re-grant the permission and run a test to resume.

## Standalone script permissions

For the LaunchAgent version, the **program that executes the AppleScript** is what
needs permission. On first manual run (`./test-automation.sh`), grant Accessibility
and Automation to that program. When launchd runs it on schedule, the same grants
apply.
