#!/usr/bin/env bash
#
# install-launch-agent.sh
#
# Installs the standalone Claude Auto Ping LaunchAgent for the current user.
# Runs entirely in user space (no root). Backs up any existing configuration
# before replacing it, validates the generated plist, and loads it with the
# modern `launchctl bootstrap` API.
#
# Usage:
#   ./install-launch-agent.sh [--interval SECONDS] [--message TEXT]
#                             [--app-name NAME] [--no-return]
#
# Defaults: interval=18000 (5 hours), message="hi", app-name="Claude",
# Return is pressed to send.

set -euo pipefail

LABEL="com.opensource.claudeautopingmacos"
SUPPORT_DIR="${HOME}/Library/Application Support/ClaudeAutoPingMacos"
LOG_DIR="${SUPPORT_DIR}/logs"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLESCRIPT_SRC="${SCRIPT_DIR}/claude-auto-ping.applescript"
APPLESCRIPT_DEST="${SUPPORT_DIR}/claude-auto-ping.applescript"

INTERVAL="18000"
MESSAGE="hi"
APP_NAME="Claude"
RETURN_MODE="return"

usage() {
	grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--interval)
			INTERVAL="${2:-}"
			shift 2
			;;
		--message)
			MESSAGE="${2:-}"
			shift 2
			;;
		--app-name)
			APP_NAME="${2:-}"
			shift 2
			;;
		--no-return)
			RETURN_MODE="noreturn"
			shift
			;;
		-h|--help)
			usage
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

# Prompt interactively for any unset values when attached to a terminal.
if [[ -t 0 ]]; then
	read -r -p "Interval in seconds [${INTERVAL}]: " reply || true
	if [[ -n "${reply}" ]]; then INTERVAL="${reply}"; fi
	read -r -p "Message [${MESSAGE}]: " reply || true
	if [[ -n "${reply}" ]]; then MESSAGE="${reply}"; fi
	read -r -p "Claude app name [${APP_NAME}]: " reply || true
	if [[ -n "${reply}" ]]; then APP_NAME="${reply}"; fi
fi

# Validate the interval is a positive integer of at least 300 seconds.
if ! [[ "${INTERVAL}" =~ ^[0-9]+$ ]]; then
	echo "Error: interval must be a positive integer (seconds)." >&2
	exit 1
fi
if (( INTERVAL < 300 )); then
	echo "Error: interval must be at least 300 seconds (5 minutes)." >&2
	exit 1
fi

if [[ ! -f "${APPLESCRIPT_SRC}" ]]; then
	echo "Error: cannot find ${APPLESCRIPT_SRC}" >&2
	exit 1
fi

mkdir -p "${SUPPORT_DIR}" "${LOG_DIR}" "${LAUNCH_AGENTS_DIR}"

# Back up an existing configuration before replacing it.
timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -f "${PLIST_DEST}" ]]; then
	cp "${PLIST_DEST}" "${PLIST_DEST}.backup.${timestamp}"
	echo "Backed up existing plist to ${PLIST_DEST}.backup.${timestamp}"
	# Unload the previous agent so it can be replaced cleanly.
	launchctl bootout "gui/$(id -u)" "${PLIST_DEST}" 2>/dev/null || true
fi

cp "${APPLESCRIPT_SRC}" "${APPLESCRIPT_DEST}"

xml_escape() {
	printf '%s' "$1" \
		| sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
			-e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

MESSAGE_XML="$(xml_escape "${MESSAGE}")"
APP_NAME_XML="$(xml_escape "${APP_NAME}")"
SCRIPT_XML="$(xml_escape "${APPLESCRIPT_DEST}")"
LOG_XML="$(xml_escape "${LOG_DIR}")"

# Write the plist directly with escaped values rather than relying on sed
# substitution into the template, which avoids delimiter issues with arbitrary
# message text.
cat > "${PLIST_DEST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/osascript</string>
		<string>${SCRIPT_XML}</string>
		<string>${MESSAGE_XML}</string>
		<string>${APP_NAME_XML}</string>
		<string>${RETURN_MODE}</string>
	</array>
	<key>StartInterval</key>
	<integer>${INTERVAL}</integer>
	<key>RunAtLoad</key>
	<false/>
	<key>StandardOutPath</key>
	<string>${LOG_XML}/stdout.log</string>
	<key>StandardErrorPath</key>
	<string>${LOG_XML}/stderr.log</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF

# Validate before loading.
if ! plutil -lint "${PLIST_DEST}" >/dev/null; then
	echo "Error: generated plist failed validation." >&2
	exit 1
fi

# Load with the modern API.
launchctl bootstrap "gui/$(id -u)" "${PLIST_DEST}"

echo ""
echo "Installed Claude Auto Ping LaunchAgent."
echo "  Label:    ${LABEL}"
echo "  Interval: ${INTERVAL} seconds"
echo "  Message:  ${MESSAGE}"
echo "  App name: ${APP_NAME}"
echo "  Plist:    ${PLIST_DEST}"
echo "  Logs:     ${LOG_DIR}"
echo ""
echo "Permissions required (grant once, then it runs unattended):"
echo "  1. System Settings > Privacy & Security > Accessibility"
echo "     - Enable access for the program that posts keystrokes (osascript /"
echo "       Terminal on first manual run; the agent uses System Events)."
echo "  2. System Settings > Privacy & Security > Automation"
echo "     - Allow control of 'System Events' and '${APP_NAME}'."
echo ""
echo "Test it now with:"
echo "  osascript \"${APPLESCRIPT_DEST}\" \"${MESSAGE}\" \"${APP_NAME}\" noreturn"
echo ""
echo "Uninstall with: ./uninstall-launch-agent.sh"
