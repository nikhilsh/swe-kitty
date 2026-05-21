# Terminal renderer rewrite — Ghostty libghostty pick

## Status

Stage 0 spike (feature-flag scaffold) in progress. Stage 1+ deferred.

## Why rewrite (again)

The xterm.js path (Stage F', `PLAN-TERMINAL-XTERMJS.md`) ships, but it
carries WKWebView baggage we'd rather not carry forever on iOS:

- WKWebView spin-up cost dominates first-frame time when a session is
  attached cold; we already paper over this with snapshot replay.
- The JS bridge is async-everywhere; every keystroke and resize crosses
  a postMessage boundary. Latency is fine for chat-shaped terminals
  but visible for fast-scroll TUIs.
- We can't ship a single rendering primitive across iOS + Android;
  Android already has its own native view, so the JS path is iOS-only
  and forks the rendering story.
- Selection, link-tap, mouse reporting, and accessibility are
  all xterm.js extension hooks we'd have to write a Swift bridge for —
  they're stragglers we keep punting.

A native VT emulator + native render layer fixes all of the above and
sets up a path to share the same C surface with Android via JNI later.

## Pick — Ghostty's libghostty

Two real candidates surveyed:

- **SwiftTerm** — what we used before Stage F'. Pure-Swift, single-
  maintainer, mid-stream replay is broken (the vertical-stripe bug
  that pushed us to xterm.js). Rejected.
- **Ghostty `libghostty`** — Mitchell Hashimoto's emulator, written
  in Zig, exposes a C ABI and ships a prebuilt xcframework as a
  GitHub release asset. Battle-tested by the macOS Ghostty app.
  Roadmap mentions an iOS Ghostty shell with a public reference
  impl at `macos/Sources/App/iOS/iOSApp.swift`.

Picking Ghostty.

## §E — Decisions table

| Decision                             | Choice                                                                                    | Rationale |
| ------------------------------------ | ----------------------------------------------------------------------------------------- | --------- |
| Emulator library                     | Ghostty `libghostty` (via `ghostty-vt.xcframework` / `GhosttyKit.xcframework`)            | Mature VT, C ABI, prebuilt iOS slices. |
| Distribution                         | SPM `binaryTarget` URL + checksum from a Ghostty GitHub release asset                     | Avoids checking a 9MB+ binary into git, lets us pin a version. |
| Build-locally fallback               | `zig build -Demit-xcframework` against a checked-out Ghostty source tree                  | Last resort if no upstream release fits. |
| Render layer (Stage 1)               | `CAMetalLayer` driven by a Swift rendering shim, fed by Ghostty's grid/state              | Matches Ghostty's macOS path; reuses upstream's tested glyph cache once ported. |
| Render fallback (Stage 0/Stage 1.5)  | Reuse xterm.js for pixels, use Ghostty only as the VT emulator (feed-and-serialize)       | De-risks renderer work — we can land the VT half first. |
| Input pipeline                       | UIView with `inputAccessoryView`, route keystrokes through `Ghostty.Surface` C API        | Matches existing `KeyableWKWebView` shape so the accessory bar stays. |
| Feature flag                         | `AppearanceStore.experimentalNativeTerminal` (UserDefaults), default off                  | Ship-while-it's-rough; one-line revert if it regresses. |
| xterm.js path                        | Stays compiled and reachable while the flag is off, for at least one release after the new path ships | Same one-release-fallback discipline used during SwiftTerm → xterm.js. |
| Wire protocol                        | Unchanged — broker still ships raw bytes, client still owns terminal emulation            | Stage F's per-cell idea is still off the table. |
| Snapshot/restore                     | Ghostty's `terminal_serialize` C API (or equivalent) — emit ANSI for cross-attach replay | Drop-in replacement for xterm.js's SerializeAddon. |

## Staging

- **Stage 0 — feasibility spike (THIS PR).** Pin the SPM binary
  target, wire a feature flag, expose a `GhosttyTerminalView`
  placeholder behind the flag, prove the wiring shape compiles +
  renders something. No PTY wiring, no rendering, no input — just
  prove we can load the framework and instantiate the view.
- **Stage 1 — VT-only emulator wired to xterm.js renderer.** Feed
  bytes into `libghostty`, ask it for serialized state, route that
  state to xterm.js for rendering. Keeps the JS pixel path while
  retiring the JS VT emulator. Lets us validate Ghostty's VT
  against real harness output before tackling pixels.
- **Stage 2 — native renderer.** Replace the xterm.js renderer with
  a `CAMetalLayer`-backed shim. Selection, link-tap, mouse, accessibility
  routed through native APIs.
- **Stage 3 — Android.** Same C library through JNI; Kotlin
  render shim. Out of scope for the iOS branch.
- **Stage 4 — retire xterm.js.** Once Stage 2 has shipped on iOS
  for one release with no rollback, drop `Sources/Resources/terminal/`
  and the WKTerminalView path.

## Risk log

- `GhosttyKit.xcframework` — the full kit with `Surface`, Metal, etc —
  is not (currently) shipped as a release asset. Only `ghostty-vt.xcframework`
  (the VT emulator C lib) is. That's enough for Stage 1 but not Stage 2.
  Building the full kit requires the Zig toolchain in CI, which we
  don't have. Mitigation: Stage 1 only needs the VT slice, so we can
  start there; defer the renderer slice to a follow-up that builds
  Ghostty from source or waits for upstream to ship a wider xcframework.
- Ghostty releases are cut as `tip` (nightly) — there is no stable
  semver tag with an xcframework asset. We'd have to either pin
  to a Ghostty commit + build from source, or pin to an asset URL
  with a known sha256 and accept that upstream may overwrite `tip`.
- CI cost: building Ghostty from source on every CI run is a non-
  starter. Either we ship the prebuilt asset path or we vendor a
  cached xcframework in releases of our own.

## Files touched by Stage 0

- `apps/ios/Sources/Models/AppearanceStore.swift` — flag.
- `apps/ios/Sources/Views/SettingsSheet.swift` — toggle row.
- `apps/ios/Sources/Views/GhosttyTerminalView.swift` — placeholder view.
- `apps/ios/Sources/Views/ProjectView.swift` — flag-gated branch in
  `tabContent`.
- `scripts/fetch-ghostty-vt-xcframework.sh` — fetch helper for the
  Ghostty `ghostty-vt.xcframework.zip` release asset.
- `apps/ios/Tests/SweKittyTests/AppearanceStoreTests.swift` — flag
  persistence + default.

The xterm.js path (`WKTerminalView`, `TerminalTabXterm`) is **untouched**
and remains the default. Toggling the flag off restores the old behavior
within a SwiftUI re-render.

## Stage 0 status — 2026-05-21

**What worked**

- Feature flag (`experimentalNativeTerminal`) added to
  `AppearanceStore`, persisted to UserDefaults, defaults `false`.
- Toggle row landed in the `ExperimentalFeaturesSheet` opened from
  Settings → Experimental → Experimental Features.
- `GhosttyTerminalView` exists as a SwiftUI `UIViewRepresentable`
  scaffold with a black-background `UIView` and a hard-coded status
  label ("GhosttyKit not yet integrated — see PLAN-TERMINAL-REWRITE
  Stage 0").
- `ProjectView.tabContent` reads the flag and dispatches to
  `GhosttyTerminalView` when it's on; the xterm.js path runs
  otherwise. Default-off ⇒ no behavior change for current users.
- `scripts/fetch-ghostty-vt-xcframework.sh` documents the canonical
  fetch + checksum step. The sha256 of the `tip` release asset at
  the time of writing is captured in the script.
- Test added asserting flag default + UserDefaults round-trip.

**What's blocked / deferred**

- **The xcframework is NOT actually wired into the Xcode project
  yet.** project.yml expects `framework: …` paths checked into the
  worktree; we don't want to commit a 9MB binary, and we don't have
  an SPM `binaryTarget` URL slot in xcodegen's `packages` block
  (it accepts named SPM packages, not raw binaryTarget URLs).
  Resolving this properly needs one of: (a) a tiny local SPM
  wrapper package (`apps/ios/GhosttyVT/Package.swift`) that hosts
  the binaryTarget; (b) extending `build-rust.sh` to fetch and
  unzip the asset before xcodegen runs. Either is mechanical and
  punted to Stage 1.
- The available release asset is `ghostty-vt.xcframework.zip`, which
  is the slim VT-only build — it does **not** include `Ghostty.Surface`,
  the Metal renderer, or the input/key APIs Ghostty's own iOS shell
  uses. The full `GhosttyKit.xcframework` is not (currently)
  published as a release asset. So even after wiring the binary,
  the SwiftUI view can't instantiate a `Ghostty.Surface` without
  also pulling in upstream Swift wrappers and writing our own
  renderer.
- `iOSApp.swift` from Ghostty's tree uses `GhosttyKit` (the full
  module). The reference implementation we wanted to mirror is not
  reachable from `ghostty-vt` alone.

**What's queued for Stage 1**

- Add `apps/ios/GhosttyVT/Package.swift` exposing the prebuilt
  `ghostty-vt.xcframework` as an SPM `binaryTarget` with a pinned
  URL + checksum; add it to `project.yml` packages.
- Write a thin Swift wrapper (`GhosttyVT.swift`) over the C API
  (`ghostty_terminal_new`, `ghostty_terminal_write`, …).
- Wire `GhosttyTerminalView` to feed PTY bytes into the libghostty
  terminal and call `ghostty_terminal_serialize` for snapshot output,
  routing the resulting ANSI back into the existing xterm.js
  renderer (Stage 1 of the staging plan).
- Decide between (a) waiting for upstream to ship a full
  `GhosttyKit.xcframework` release asset, or (b) standing up our
  own CI job that runs `zig build -Demit-xcframework` against a
  pinned Ghostty commit, before tackling Stage 2 (native render).
