# Troubleshooting

Use **Settings → Logs** first — each run records which step succeeded (launch, new
chat, paste, send) without storing your message content.

## Claude is not found

- Open **Settings → Automation** and click **Detect Claude**.
- If detection fails, click **Choose Claude App…** and select Claude manually
  (works for `/Applications` and `~/Applications`).
- The app matches by candidate bundle ids and by app name; a renamed bundle still
  works via the manual path.

## Nothing gets pasted / the message goes to the wrong app

- Confirm **Accessibility** and **Automation** permissions (Settings →
  Permissions). See [permissions.md](permissions.md).
- Run a **Dry-run test** (Automation tab). It performs every step except pressing
  Return.
- Increase **New-chat delay** and **Send delay** if Claude opens slowly.

## The new chat does not open

- Claude may have changed its new-chat shortcut. Update it in
  **Settings → Automation → New chat shortcut** (default ⌘N).

## It paused itself

- After three consecutive failures the scheduler auto-pauses to avoid repeated
  actions. Fix the underlying cause, run a **Full send test**, then **Resume**.

## Nothing happens while the Mac is asleep or locked

- Automation cannot run while the Mac is locked; the run is skipped and retried at
  the next interval. With **wake recovery** enabled, at most one catch-up message
  is sent after waking.

## Permission was granted but still fails

- Toggle the app off and on in the Accessibility list, or remove and re-add it.
- After a macOS or Claude update, permissions sometimes need re-granting.

## Standalone LaunchAgent issues

- Check logs at `~/Library/Application Support/ClaudeAutoPingMacos/logs/`
  (`stdout.log`, `stderr.log`).
- Verify it is loaded: `launchctl print "gui/$(id -u)/com.opensource.claudeautopingmacos"`.
- Reinstall: `./Scripts/uninstall-launch-agent.sh && ./Scripts/install-launch-agent.sh`.

## Reporting a UI breakage

Claude UI updates can break automation. Open a **Bug report** with your macOS and
Claude versions, sanitized logs, and (if known) the working shortcut/delays.
