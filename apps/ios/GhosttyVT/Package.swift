// swift-tools-version:5.10
//
// Stage 2 unblock — pin Lakr233/libghostty-spm's multi-arch
// `GhosttyKit.xcframework.zip` release asset. The previous pin
// (ghostty-org/ghostty's `tip` `ghostty-vt.xcframework.zip`) was
// disabled in PR #94 because upstream's lib-vt build only ships an
// `ios-arm64/` slice — no `ios-arm64_x86_64-simulator` slice —
// so xcodebuild for the iOS simulator linker fails with
// "building for 'iOS-simulator', but linking in object file built
// for 'iOS'". See `docs/PLAN-TERMINAL-REWRITE.md` →
// "Stage 2 unblock — how others build the xcframework" (PR #96) for
// the full survey of upstream + community options that lead to this
// pick.
//
// Lakr233's pipeline (`.github/workflows/build.yml` in
// libghostty-spm) cross-compiles libghostty for the full
// {ios-arm64, ios-arm64-simulator, ios-x86_64-simulator,
//  macos-arm64, macos-x86_64, ios-arm64-macabi, ios-x86_64-macabi}
// matrix on `macos-15`, stitches with
// `xcodebuild -create-xcframework`, and publishes the zip as
// `storage.<version>` immutable release tags downstream of upstream
// Ghostty semver tags. License: MIT (the SPM wrapper); Ghostty
// itself is MIT.
//
// **API-surface gap (intentional).**
// The xcframework's module is named `libghostty` (per its umbrella
// modulemap: `framework module libghostty { umbrella header
// "ghostty.h" export * }`) and exposes the full Ghostty `App` /
// `Surface` / `Inspector` C API surface (`ghostty_app_new`,
// `ghostty_surface_new`, `ghostty_surface_write_buffer`, …) — NOT
// the slim VT-only surface our existing `Terminal.swift` wrapper
// drives (`ghostty_terminal_new`, `ghostty_terminal_vt_write`,
// `ghostty_terminal_grid_ref`, …). Bridging Swift to the App/Surface
// shape requires an event loop, a runtime config, and a host window;
// it's a Stage 3 rewrite, not a pin PR.
//
// To keep the iOS app compiling today without dropping the link, the
// `GhosttyVT` Swift target declares `libghostty` as a dependency so
// SPM resolves + fetches the xcframework, but `Terminal.swift` and
// `GhosttyTerminalView.swift` keep their `#if canImport(GhosttyVt)`
// guard. That guard evaluates `false` against this pin (the module
// is `libghostty`, not `GhosttyVt`), so the placeholder path takes
// over and the build stays green. The full bridge to the App/Surface
// API is queued for the next PR; this one only swaps the pin to a
// resolvable multi-arch source.
//
// **Pin source** (matches `scripts/fetch-ghostty-kit-xcframework.sh`):
//   URL:      https://github.com/Lakr233/libghostty-spm/releases/download/storage.1.1.5/GhosttyKit.xcframework.zip
//   sha256:   a7045bef1f3149989d79e413b07f2f17847d68348da9f55eb56578093a5af405
//   Source:   Lakr233's published `Package.swift` (binaryTarget
//             checksum field) + verified against the live asset by
//             `curl -fsSL <url> | shasum -a 256` on 2026-05-22.
//   Tag:      `storage.1.1.5` (downstream of upstream Ghostty
//             `v1.3.1`, sha 332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28).
//
// Bump cadence: Lakr233's pipeline cron is weekly Mondays; pin once
// per upstream Ghostty semver tag, not per upstream cut. If Lakr233
// ever stops publishing, fall back to Option A in §"Stage 2 unblock"
// — copy their build matrix into our own GitHub Actions job.
import PackageDescription

let package = Package(
    name: "GhosttyVT",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GhosttyVT", targets: ["GhosttyVT"]),
    ],
    targets: [
        // Multi-arch xcframework from Lakr233's libghostty-spm
        // pipeline — see file header for full attribution + the
        // rationale for picking this over upstream's `tip` asset.
        // Slices included (verified by extracting Info.plist of the
        // 2026-05-22 storage.1.1.5 asset):
        //   ios-arm64
        //   ios-arm64_x86_64-simulator
        //   ios-arm64_x86_64-maccatalyst
        //   macos-arm64_x86_64
        // The xcodebuild iOS-simulator linker now finds matching
        // slices (this was PR #94's blocker against upstream's
        // arm64-only `tip` build).
        .binaryTarget(
            name: "libghostty",
            url: "https://github.com/Lakr233/libghostty-spm/releases/download/storage.1.1.5/GhosttyKit.xcframework.zip",
            checksum: "a7045bef1f3149989d79e413b07f2f17847d68348da9f55eb56578093a5af405"
        ),
        // Thin Swift wrapper. Re-exports the C symbols through a
        // typed Swift API (Terminal class + TerminalSnapshot struct).
        //
        // The `#if canImport(GhosttyVt)` guard in Terminal.swift +
        // GhosttyTerminalView.swift evaluates `false` against this
        // pin (Lakr233's xcframework exposes the `libghostty` module,
        // not `GhosttyVt`), so the placeholder path stays live until
        // a follow-up PR rewrites the wrapper to the App/Surface API.
        // That's deliberate — see the file header for the API-surface
        // gap rationale. The dependency keeps SPM resolution exercising
        // the link path so a stale checksum surfaces immediately on
        // build, not at runtime.
        .target(
            name: "GhosttyVT",
            dependencies: ["libghostty"],
            path: "Sources/GhosttyVT"
        ),
        .testTarget(
            name: "GhosttyVTTests",
            dependencies: ["GhosttyVT"],
            path: "Tests/GhosttyVTTests"
        ),
    ]
)
