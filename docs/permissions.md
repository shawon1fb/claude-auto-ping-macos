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

## Revoked permissions

If you later revoke Accessibility, scheduled runs fail safely: the app records a
clear error, surfaces the "permission required" state, and does not retry in a
loop. Re-grant the permission and run a test to resume.

## Standalone script permissions

For the LaunchAgent version, the **program that executes the AppleScript** is what
needs permission. On first manual run (`./test-automation.sh`), grant Accessibility
and Automation to that program. When launchd runs it on schedule, the same grants
apply.
