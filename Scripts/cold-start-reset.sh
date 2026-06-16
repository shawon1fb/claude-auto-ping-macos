#!/usr/bin/env bash
#
# cold-start-reset.sh
#
# Resets Claude Auto Ping to a clean first-run state for the current user:
# quits the app, resets its macOS privacy permissions (Accessibility, Automation,
# Notifications), and clears its saved settings, state, and logs. Runs in user
# space (no sudo). It does not delete the app bundle itself.
#
# Usage:
#   ./Scripts/cold-start-reset.sh

set -euo pipefail

BUNDLE_ID="com.opensource.claudeautopingmacos"
PROCESS_NAME="ClaudeAutoPingMacos"
SUPPORT_DIR="${HOME}/Library/Application Support/ClaudeAutoPingMacos"

echo "==> Quitting the app if it is running"
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" 2>/dev/null || true
pkill -x "${PROCESS_NAME}" 2>/dev/null || true
sleep 1

echo "==> Resetting macOS privacy permissions (TCC) for ${BUNDLE_ID}"
# Reset every recorded permission for this app. Individual services are reset
# too in case 'All' is unsupported for a given macOS version.
tccutil reset All "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset AppleEvents "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset Notifications "${BUNDLE_ID}" 2>/dev/null || true

echo "==> Clearing saved settings and scheduler state"
defaults delete "${BUNDLE_ID}" 2>/dev/null || true

echo "==> Removing logs and support files"
rm -rf "${SUPPORT_DIR}"

echo ""
echo "Cold start complete. Claude Auto Ping is back to a clean first-run state."
echo "Reopen it to start fresh:"
echo "  open build/ClaudeAutoPingMacos.app"
echo ""
echo "Note: the login item, if it was enabled, is cleared on next launch when"
echo "settings reset. The standalone LaunchAgent (if installed) is separate —"
echo "remove it with ./uninstall-launch-agent.sh."
