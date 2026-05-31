import SwiftUI

// MARK: - ConduitUI namespace
//
// The ConduitUI tree is the upstream-faithful UI rebuild — a parallel view
// surface that runs entirely off the existing `SessionStore` +
// `AppearanceStore` data layer. We accumulated ~30 PRs of drift on the
// legacy `RootView` / `HomeView` and the visual feel had stopped
// resembling upstream; the cleanest path forward was to retire those
// views (kept on disk, but behind `experimentalConduitUI` defaulting
// OFF) and rebuild from scratch.
//
// Naming policy: every type that lives under `apps/ios/Sources/ConduitUI`
// is nested inside this `enum ConduitUI` so we cannot accidentally
// shadow a symbol already in use by the legacy view layer
// (`HomeView`, `ProjectView`, `SettingsSheet`, etc.) — both trees ship
// in the same binary while the flag-flip is staged.
//
// License posture: upstream (`https://github.com/dnakov/upstream`) is
// GPLv3 with an App Store additional permission (LICENSE checked
// 2026-05-22 via `gh api repos/dnakov/upstream/contents/LICENSE`).
// Because Conduit is not GPLv3, we cannot copy upstream source into
// this tree. Every visual decision below is a clean-room
// reimplementation: we studied upstream's structural layout (Views,
// Models/ConduitPalette, Extensions glass modifiers) via the
// `dnakov/upstream` GitHub API + raw.githubusercontent.com source
// reads, then wrote our own SwiftUI. File-level headers document
// the upstream file each new view structurally mirrors.

enum ConduitUI {
    /// Marker so other modules can detect the namespace exists at
    /// compile time (mainly used by tests).
    static let namespaceMarker: String = "ConduitUI"
}
