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
# Module name MUST match the UDL namespace ("swe_kitty_core") + "FFI" suffix:
# the UniFFI-generated Swift wrapper hardcodes `import swe_kitty_coreFFI` and
# relies on its C typedefs (RustBuffer, RustCallStatus, ForeignBytes) being in
# scope. Renaming the module breaks `canImport(swe_kitty_coreFFI)` silently.
MODULE_NAME="swe_kitty_coreFFI"
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

# UniFFI Swift bindings: emits swe_kitty_core.swift + swe_kitty_coreFFI.{h,modulemap}.
BINDGEN_OUT="$WORK/bindings"
mkdir -p "$BINDGEN_OUT"
( cd "$CORE_DIR" && cargo run --quiet --bin uniffi-bindgen -- \
    generate "$UDL" \
    --language swift \
    --out-dir "$BINDGEN_OUT" )

# Move the Swift wrapper out (renamed for Xcode niceties; content is unchanged
# so its `import swe_kitty_coreFFI` line still matches the C module below).
mv "$BINDGEN_OUT/swe_kitty_core.swift" "$BINDINGS_DIR/SweKittyCore.swift"

# Pass the header + UniFFI's own modulemap straight through to the xcframework.
HEADERS="$WORK/headers"
mkdir -p "$HEADERS"
cp "$BINDGEN_OUT/swe_kitty_coreFFI.h" "$HEADERS/"
cp "$BINDGEN_OUT/swe_kitty_coreFFI.modulemap" "$HEADERS/module.modulemap"

xcodebuild -create-xcframework \
  -library "$WORK/device/$LIB_NAME" -headers "$HEADERS" \
  -library "$WORK/sim/$LIB_NAME"    -headers "$HEADERS" \
  -output "$XCFW"

rm -rf "$WORK"

echo "==> done: $XCFW"
echo "==> bindings: $BINDINGS_DIR/SweKittyCore.swift"
