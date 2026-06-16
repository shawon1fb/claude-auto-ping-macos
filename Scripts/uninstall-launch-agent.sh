#!/usr/bin/env bash
#
# uninstall-launch-agent.sh
#
# Fully uninstalls Claude Auto Ping for the current user: quits the app, stops
# and removes the standalone LaunchAgent and its script, resets the app's macOS
# privacy permissions (the TCC "permission cache": Accessibility, Automation,
# Notifications), and clears saved settings. Runs in user space (no sudo) and
# never touches unrelated files. Exported logs are preserved unless --remove-logs
# is given.
#
# Usage:
#   ./uninstall-launch-agent.sh [--remove-logs] [--keep-permissions]
#                               [--remove-app PATH]
#
# Options:
#   --remove-logs        Also delete the logs directory.
#   --keep-permissions   Do NOT reset the macOS privacy permissions.
#   --remove-app PATH    Also move the given .app bundle to the Trash.

set -euo pipefail

BUNDLE_ID="com.opensource.claudeautopingmacos"
PROCESS_NAME="ClaudeAutoPingMacos"
SUPPORT_DIR="${HOME}/Library/Application Support/ClaudeAutoPingMacos"
LOG_DIR="${SUPPORT_DIR}/logs"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/${BUNDLE_ID}.plist"
APPLESCRIPT_DEST="${SUPPORT_DIR}/claude-auto-ping.applescript"
PREFS_PLIST="${HOME}/Library/Preferences/${BUNDLE_ID}.plist"

REMOVE_LOGS="false"
RESET_PERMISSIONS="true"
REMOVE_APP_PATH=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--remove-logs)
			REMOVE_LOGS="true"
			shift
			;;
		--keep-permissions)
			RESET_PERMISSIONS="false"
			shift
			;;
		--remove-app)
			if [[ $# -lt 2 || "${2:-}" == --* ]]; then
				echo "Error: --remove-app requires a .app path." >&2
				exit 1
			fi
			REMOVE_APP_PATH="${2:-}"
			shift 2
			;;
		-h|--help)
			grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

echo "==> Quitting the app if it is running"
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" 2>/dev/null || true
pkill -x "${PROCESS_NAME}" 2>/dev/null || true
sleep 1

echo "==> Stopping and removing the LaunchAgent (if installed)"
if launchctl print "gui/$(id -u)/${BUNDLE_ID}" >/dev/null 2>&1; then
	launchctl bootout "gui/$(id -u)/${BUNDLE_ID}" 2>/dev/null || true
	echo "    Stopped ${BUNDLE_ID}."
elif [[ -f "${PLIST_DEST}" ]]; then
	launchctl bootout "gui/$(id -u)" "${PLIST_DEST}" 2>/dev/null || true
fi

if [[ -f "${PLIST_DEST}" ]]; then
	rm -f "${PLIST_DEST}"
	echo "    Removed ${PLIST_DEST}."
fi

if [[ -f "${APPLESCRIPT_DEST}" ]]; then
	rm -f "${APPLESCRIPT_DEST}"
	echo "    Removed ${APPLESCRIPT_DEST}."
fi

if [[ "${RESET_PERMISSIONS}" == "true" ]]; then
	echo "==> Resetting macOS privacy permissions (TCC) for ${BUNDLE_ID}"
	tccutil reset All "${BUNDLE_ID}" 2>/dev/null || true
	tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true
	tccutil reset AppleEvents "${BUNDLE_ID}" 2>/dev/null || true
	tccutil reset Notifications "${BUNDLE_ID}" 2>/dev/null || true
else
	echo "==> Keeping macOS privacy permissions (--keep-permissions)"
fi

echo "==> Clearing saved settings and scheduler state"
defaults delete "${BUNDLE_ID}" 2>/dev/null || true
rm -f "${PREFS_PLIST}" 2>/dev/null || true

if [[ "${REMOVE_LOGS}" == "true" ]]; then
	if [[ -d "${LOG_DIR}" ]]; then
		rm -rf "${LOG_DIR}"
		echo "==> Removed logs at ${LOG_DIR}"
	fi
else
	if [[ -d "${LOG_DIR}" ]]; then
		echo "==> Preserved logs at ${LOG_DIR} (use --remove-logs to delete)"
	fi
fi

# Remove the support directory only if it is now empty.
if [[ -d "${SUPPORT_DIR}" ]]; then
	if [[ -z "$(ls -A "${SUPPORT_DIR}" 2>/dev/null)" ]]; then
		rmdir "${SUPPORT_DIR}"
		echo "==> Removed empty ${SUPPORT_DIR}"
	fi
fi

# Optionally move the app bundle to the Trash.
if [[ -n "${REMOVE_APP_PATH}" ]]; then
	if [[ -d "${REMOVE_APP_PATH}" && "${REMOVE_APP_PATH}" == *.app ]]; then
		trashed_name="$(basename "${REMOVE_APP_PATH}")"
		mkdir -p "${HOME}/.Trash"
		mv "${REMOVE_APP_PATH}" "${HOME}/.Trash/${trashed_name}.$(date +%s)" 2>/dev/null \
			&& echo "==> Moved ${REMOVE_APP_PATH} to the Trash" \
			|| echo "    Could not move ${REMOVE_APP_PATH}; remove it manually." >&2
	else
		echo "    --remove-app expects a path ending in .app; skipping." >&2
	fi
fi

echo ""
echo "Uninstall complete. Claude Auto Ping is fully removed for this user."
if [[ "${RESET_PERMISSIONS}" == "true" ]]; then
	echo "Its entries in System Settings > Privacy & Security (Accessibility,"
	echo "Automation, Notifications) have been cleared."
fi
