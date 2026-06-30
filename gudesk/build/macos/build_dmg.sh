#!/usr/bin/env bash
# Creates a distributable GuDesk.dmg from the Flutter macOS build output.
#
# Usage:
#   ./gudesk/build/macos/build_dmg.sh
#
# Environment variables:
#   VERSION   — app version string (default: read from Cargo.toml)
#   ARCH      — architecture tag  (default: auto-detected via uname -m)
#   APP_PATH  — path to the built .app bundle
#               (default: flutter/build/macos/Build/Products/Release/GuDesk.app)
#   OUT_DIR   — directory to write the .dmg into (default: target/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────
VERSION="${VERSION:-$(grep '^version' "$REPO_ROOT/Cargo.toml" | head -1 | awk -F'"' '{print $2}')}"
ARCH="${ARCH:-$(uname -m | sed 's/x86_64/x86_64/; s/arm64/aarch64/')}"
APP_PATH="${APP_PATH:-$REPO_ROOT/flutter/build/macos/Build/Products/Release/GuDesk.app}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/target}"
DMG_STAGING="$OUT_DIR/dmg_staging_$$"
OUTPUT="$OUT_DIR/GuDesk-${VERSION}-${ARCH}.dmg"

echo "Building GuDesk.dmg v${VERSION} (${ARCH})"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: .app bundle not found at $APP_PATH" >&2
  echo "Run 'flutter build macos --release' first." >&2
  exit 1
fi

# ── Stage contents ────────────────────────────────────────────────────────
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/GuDesk.app"
ln -s /Applications "$DMG_STAGING/Applications"

mkdir -p "$OUT_DIR"

# ── Create DMG ────────────────────────────────────────────────────────────
hdiutil create \
  -volname "GuDesk ${VERSION}" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT"

rm -rf "$DMG_STAGING"

echo "Created: $OUTPUT"
echo "SHA-256: $(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "Size:    $(stat -f%z "$OUTPUT") bytes"
