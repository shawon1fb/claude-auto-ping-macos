#!/usr/bin/env bash
#
# uninstall-launch-agent.sh
#
# Stops and removes the standalone Claude Auto Ping LaunchAgent and its installed
# script. Exported logs are preserved unless --remove-logs is given. Never
# touches unrelated files.
#
# Usage:
#   ./uninstall-launch-agent.sh [--remove-logs]

set -euo pipefail

LABEL="com.opensource.claudeautopingmacos"
SUPPORT_DIR="${HOME}/Library/Application Support/ClaudeAutoPingMacos"
LOG_DIR="${SUPPORT_DIR}/logs"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
APPLESCRIPT_DEST="${SUPPORT_DIR}/claude-auto-ping.applescript"

REMOVE_LOGS="false"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--remove-logs)
			REMOVE_LOGS="true"
			shift
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

# Stop the agent if it is loaded.
if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
	launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
	echo "Stopped ${LABEL}."
elif [[ -f "${PLIST_DEST}" ]]; then
	launchctl bootout "gui/$(id -u)" "${PLIST_DEST}" 2>/dev/null || true
fi

# Remove the plist.
if [[ -f "${PLIST_DEST}" ]]; then
	rm -f "${PLIST_DEST}"
	echo "Removed ${PLIST_DEST}."
fi

# Remove the installed AppleScript.
if [[ -f "${APPLESCRIPT_DEST}" ]]; then
	rm -f "${APPLESCRIPT_DEST}"
	echo "Removed ${APPLESCRIPT_DEST}."
fi

# Remove logs only if explicitly requested.
if [[ "${REMOVE_LOGS}" == "true" ]]; then
	if [[ -d "${LOG_DIR}" ]]; then
		rm -rf "${LOG_DIR}"
		echo "Removed logs at ${LOG_DIR}."
	fi
else
	if [[ -d "${LOG_DIR}" ]]; then
		echo "Preserved logs at ${LOG_DIR} (use --remove-logs to delete)."
	fi
fi

# Remove the support directory only if it is now empty.
if [[ -d "${SUPPORT_DIR}" ]]; then
	if [[ -z "$(ls -A "${SUPPORT_DIR}" 2>/dev/null)" ]]; then
		rmdir "${SUPPORT_DIR}"
		echo "Removed empty ${SUPPORT_DIR}."
	fi
fi

echo "Uninstall complete."
