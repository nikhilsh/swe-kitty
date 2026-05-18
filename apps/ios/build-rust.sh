#!/usr/bin/env bash
# Build SweKittyCore.xcframework + Swift bindings from core/.
#
# Output (all under apps/ios/SweKittyCore/):
#   SweKittyCore.xcframework            consumed by xcodegen via project.yml
#   Sources/SweKittyCore.swift          UniFFI-generated Swift API
#
# Triple coverage (litter pattern):
#   - aarch64-apple-ios       device       (one slice)
#   - aarch64-apple-ios-sim   sim arm64    \ lipo'd into one slice
#   - x86_64-apple-ios        sim x86_64   /
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$REPO_ROOT/core"
OUT_DIR="$SCRIPT_DIR/SweKittyCore"
XCFW="$OUT_DIR/SweKittyCore.xcframework"
BINDINGS_DIR="$OUT_DIR/Sources"

LIB_NAME="libswe_kitty_core.a"
MODULE_NAME="SweKittyCoreFFI"
UDL="$CORE_DIR/src/swe_kitty_core.udl"

PROFILE="${RUST_PROFILE:-release}"
CARGO_PROFILE_FLAG=$([ "$PROFILE" = "release" ] && echo "--release" || echo "")

echo "==> build-rust.sh: profile=$PROFILE core=$CORE_DIR out=$OUT_DIR"

if [[ ! -f "$CORE_DIR/Cargo.toml" ]]; then
  echo "build-rust.sh: core/Cargo.toml missing" >&2
  exit 1
fi

TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)

for t in "${TARGETS[@]}"; do
  echo "==> cargo build --target $t"
  ( cd "$CORE_DIR" && cargo build $CARGO_PROFILE_FLAG --target "$t" --lib )
done

WORK="$OUT_DIR/.build"
rm -rf "$WORK" "$XCFW"
mkdir -p "$WORK/sim" "$WORK/device" "$BINDINGS_DIR"

# Fat simulator slice (arm64 + x86_64).
lipo -create \
  "$CORE_DIR/target/aarch64-apple-ios-sim/$PROFILE/$LIB_NAME" \
  "$CORE_DIR/target/x86_64-apple-ios/$PROFILE/$LIB_NAME" \
  -output "$WORK/sim/$LIB_NAME"

cp "$CORE_DIR/target/aarch64-apple-ios/$PROFILE/$LIB_NAME" "$WORK/device/$LIB_NAME"

# UniFFI Swift bindings: emits SweKittyCore.swift + SweKittyCoreFFI.h + .modulemap.
BINDGEN_OUT="$WORK/bindings"
mkdir -p "$BINDGEN_OUT"
( cd "$CORE_DIR" && cargo run --quiet --bin uniffi-bindgen -- \
    generate "$UDL" \
    --language swift \
    --out-dir "$BINDGEN_OUT" )

# Move the Swift wrapper out, keep header + modulemap for the framework's headers/.
mv "$BINDGEN_OUT/swe_kitty_core.swift" "$BINDINGS_DIR/SweKittyCore.swift"

HEADERS="$WORK/headers"
mkdir -p "$HEADERS"
cp "$BINDGEN_OUT/swe_kitty_coreFFI.h" "$HEADERS/$MODULE_NAME.h"

# UniFFI's modulemap references the bindgen filename; rewrite for our renamed header + module.
cat > "$HEADERS/module.modulemap" <<MOD
module $MODULE_NAME {
    header "$MODULE_NAME.h"
    export *
}
MOD

xcodebuild -create-xcframework \
  -library "$WORK/device/$LIB_NAME" -headers "$HEADERS" \
  -library "$WORK/sim/$LIB_NAME"    -headers "$HEADERS" \
  -output "$XCFW"

rm -rf "$WORK"

echo "==> done: $XCFW"
echo "==> bindings: $BINDINGS_DIR/SweKittyCore.swift"
