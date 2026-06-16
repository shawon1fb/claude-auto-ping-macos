# Security Policy

## Reporting a vulnerability

**Do not open a public issue for security reports**, and **never include
credentials, tokens, cookies, or personal data** in any issue or pull request.

To report a vulnerability privately, email:

```
security@example.com   <-- REPLACE THIS with the maintainer's security contact
```

> Maintainers: replace the placeholder address above before publishing the
> repository. Consider enabling GitHub Private Vulnerability Reporting as well.

Please include:

- A description of the issue and its impact.
- Steps to reproduce (sanitized — no secrets).
- Affected version (see `CHANGELOG.md`) and macOS version.

We aim to acknowledge reports within a reasonable time and will coordinate a fix
and disclosure timeline with you.

## Supported versions

This project is pre-1.0. Only the latest released version (currently the `0.1.x`
line) receives security fixes.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Security model and risks

Claude Auto Ping performs **local UI automation only**. It has no network access,
no backend, and no account system. Even so, please be aware of the following:

### UI automation risks

- The app sends synthetic keyboard events (new chat, paste, Return) to the
  frontmost app. Misconfiguration (for example, the wrong app in front) could send
  keystrokes to an unintended window. The app activates Claude and waits for it to
  be frontmost before acting, and a dry-run test is provided to verify setup.
- Accessibility and Automation permissions are powerful. Grant them only if you
  trust this build. Building from source lets you audit exactly what runs.

### Clipboard behavior

- To paste your message, the app temporarily places it on the system clipboard,
  pastes with Command+V, and then restores the previous clipboard contents.
- Restoration captures the first pasteboard item's representations; exotic
  multi-item clipboards may not be perfectly restored. The message itself is your
  configured text, not anything read from elsewhere.

### What it never does

- It does not collect credentials, read Claude conversations or responses, access
  browser cookies, send analytics, or contact any backend.
- It does not attempt to bypass usage limits or automate login/CAPTCHA flows.
