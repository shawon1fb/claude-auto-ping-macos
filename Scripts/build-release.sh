#!/usr/bin/env bash
#
# build-release.sh
#
# Builds a Release .app of Claude Auto Ping macOS into ./build. Signing and
# notarization are intentionally left to the maintainer (see docs/release-
# process.md); this produces an unsigned build suitable for local use and as a
# starting point for a signed release.
#
# Usage:
#   ./build-release.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${ROOT_DIR}/ClaudeAutoPingMacos.xcodeproj"
SCHEME="ClaudeAutoPingMacos"
BUILD_DIR="${ROOT_DIR}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

if [[ ! -d "${PROJECT}" ]]; then
	echo "Error: ${PROJECT} not found. Run 'xcodegen generate' first." >&2
	exit 1
fi

mkdir -p "${BUILD_DIR}"

echo "Building Release..."
xcodebuild \
	-project "${PROJECT}" \
	-scheme "${SCHEME}" \
	-configuration Release \
	-derivedDataPath "${DERIVED_DATA}" \
	-destination 'platform=macOS' \
	CODE_SIGNING_ALLOWED=NO \
	build

APP_PATH="${DERIVED_DATA}/Build/Products/Release/ClaudeAutoPingMacos.app"
if [[ ! -d "${APP_PATH}" ]]; then
	echo "Error: build did not produce an app bundle." >&2
	exit 1
fi

cp -R "${APP_PATH}" "${BUILD_DIR}/"
FINAL_APP="${BUILD_DIR}/ClaudeAutoPingMacos.app"

# Sign with a stable identity when provided. This matters for Accessibility /
# Automation permissions: macOS TCC keys grants to the app's code signature, so
# an ad-hoc build (the default) gets a NEW identity on every rebuild and must be
# re-granted. Signing with a stable identity (a real Developer ID, an "Apple
# Development" cert, or a self-signed code-signing cert) keeps grants across
# rebuilds.
#
#   CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./Scripts/build-release.sh
#   CODESIGN_IDENTITY="My Self-Signed Cert" ./Scripts/build-release.sh
ENTITLEMENTS="${ROOT_DIR}/App/ClaudeAutoPingMacos.entitlements"
IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -n "${IDENTITY}" ]]; then
	echo "Signing with identity: ${IDENTITY}"
	codesign --force --deep --options runtime --timestamp \
		--entitlements "${ENTITLEMENTS}" \
		--sign "${IDENTITY}" \
		"${FINAL_APP}"
else
	echo "No CODESIGN_IDENTITY set; ad-hoc signing (Accessibility/Automation"
	echo "grants will not persist across rebuilds — see docs/permissions.md)."
	codesign --force --deep --options runtime \
		--entitlements "${ENTITLEMENTS}" \
		--sign - \
		"${FINAL_APP}"
fi

codesign --verify --strict --verbose=1 "${FINAL_APP}" || true
echo "Built app: ${FINAL_APP}"
