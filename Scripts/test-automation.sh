#!/usr/bin/env bash
#
# test-automation.sh
#
# Runs the standalone AppleScript once to verify Claude automation works. By
# default it performs a dry run (no Return is pressed) so nothing is sent.
#
# Usage:
#   ./test-automation.sh [--message TEXT] [--app-name NAME] [--send]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLESCRIPT="${SCRIPT_DIR}/claude-auto-ping.applescript"

MESSAGE="hi"
APP_NAME="Claude"
RETURN_MODE="noreturn"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--message)
			MESSAGE="${2:-}"
			shift 2
			;;
		--app-name)
			APP_NAME="${2:-}"
			shift 2
			;;
		--send)
			RETURN_MODE="return"
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

if [[ ! -f "${APPLESCRIPT}" ]]; then
	echo "Error: cannot find ${APPLESCRIPT}" >&2
	exit 1
fi

echo "Running automation test (mode: ${RETURN_MODE})..."
if osascript "${APPLESCRIPT}" "${MESSAGE}" "${APP_NAME}" "${RETURN_MODE}"; then
	echo "Automation test completed."
else
	echo "Automation test failed. Check Accessibility and Automation permissions." >&2
	exit 1
fi
