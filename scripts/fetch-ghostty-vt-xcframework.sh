#!/usr/bin/env bash
# Fetch ghostty-vt.xcframework from a pinned Ghostty release asset and
# extract it under apps/ios/GhosttyVT/. Stage 0 of the terminal
# rewrite (see docs/PLAN-TERMINAL-REWRITE.md) doesn't actually consume
# the framework yet — Stage 1 will wire it into project.yml via an
# SPM binaryTarget wrapper package. This script lives at HEAD so the
# wiring path is documented and the checksum is pinned.
#
# The asset is hosted on the Ghostty "tip" (nightly) tag. Upstream
# overwrites that tag on every nightly cut, so the checksum below
# will go stale; whenever it does, re-pin against the new tip and
# update both this script and Package.swift (once it lands).
#
# Usage:
#   scripts/fetch-ghostty-vt-xcframework.sh           # fetch + verify
#   scripts/fetch-ghostty-vt-xcframework.sh --check   # verify only
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/apps/ios/GhosttyVT"
ZIP_PATH="$OUT_DIR/ghostty-vt.xcframework.zip"
XCFW_PATH="$OUT_DIR/ghostty-vt.xcframework"

# Pinned against the Ghostty "tip" release as of 2026-05-20. If
# upstream cuts a new nightly, both URL host and checksum stay valid
# until the asset is re-uploaded; verify with `shasum -a 256` if a
# checksum-mismatch error surfaces.
ASSET_URL="https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-vt.xcframework.zip"
EXPECTED_SHA256="679ef4c585d4d9bfd27fd2f1c93494e783cf756678976bf2ab5995f6521c3544"

MODE="${1:-fetch}"

mkdir -p "$OUT_DIR"

case "$MODE" in
  --check|check)
    if [[ ! -f "$ZIP_PATH" ]]; then
      echo "fetch-ghostty-vt-xcframework: zip not present at $ZIP_PATH" >&2
      exit 1
    fi
    ;;
  fetch|*)
    echo "==> fetching $ASSET_URL"
    curl -fsSL "$ASSET_URL" -o "$ZIP_PATH"
    ;;
esac

ACTUAL_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "fetch-ghostty-vt-xcframework: sha256 mismatch" >&2
  echo "  expected: $EXPECTED_SHA256" >&2
  echo "  actual:   $ACTUAL_SHA256" >&2
  echo "  (upstream may have rotated the 'tip' asset; re-pin if so)" >&2
  exit 2
fi

if [[ ! -d "$XCFW_PATH" || "$MODE" != "check" ]]; then
  rm -rf "$XCFW_PATH"
  ( cd "$OUT_DIR" && /usr/bin/unzip -q "$ZIP_PATH" )
fi

echo "==> done: $XCFW_PATH"
echo "    sha256(zip) = $ACTUAL_SHA256"
echo
echo "Stage 0 spike: nothing in project.yml consumes this xcframework yet."
echo "Stage 1 will add an SPM binaryTarget wrapper at apps/ios/GhosttyVT/Package.swift"
echo "pointing at the same URL + checksum so SPM does the fetch instead of this script."
