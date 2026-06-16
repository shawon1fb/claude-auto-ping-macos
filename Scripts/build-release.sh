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
if [[ -d "${APP_PATH}" ]]; then
	cp -R "${APP_PATH}" "${BUILD_DIR}/"
	echo "Built app: ${BUILD_DIR}/ClaudeAutoPingMacos.app"
else
	echo "Error: build did not produce an app bundle." >&2
	exit 1
fi
