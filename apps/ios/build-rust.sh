#!/usr/bin/env bash
# Build SweKittyCore.xcframework from the Rust core crate.
# Until core/ exists, this is a no-op so the iOS build pipeline can be exercised end-to-end.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_DIR="$REPO_ROOT/core"

if [[ ! -f "$CORE_DIR/Cargo.toml" ]]; then
  echo "build-rust.sh: core/Cargo.toml not present; skipping xcframework build (scaffold mode)."
  exit 0
fi

echo "build-rust.sh: TODO — implement xcframework build once core/ has a cdylib target." >&2
exit 0
