import Foundation

// MARK: - LitterHomeViewModel
//
// Pure-data view-model for LitterUI's home screen. Computes the row
// list, top-bar context, and empty-state messaging from the input
// snapshot. Lives off SwiftUI so we can drive it from XCTest /
// Swift Testing without standing up a view tree.
//
// The shape (snapshot in -> rows out) mirrors what we already do for
// `SessionsScreenModel` etc. — it lets the SwiftUI view stay a thin
// renderer.

extension LitterUI {

    /// One row in the home list.
    struct HomeRow: Equatable, Identifiable {
        enum Kind: Equatable {
            case session(id: String)
            case creatingPlaceholder(id: String)
        }
        var kind: Kind
        /// Prominent friendly name (never a raw UUID — resolved upstream
        /// by `SessionStore.displayName(for:)`).
        var title: String
        /// Agent label for the secondary-line chip ("claude", "codex").
        /// Empty for placeholder rows.
        var agent: String
        /// Human status word for the secondary line: "running" / "idle" /
        /// "exited" (or the placeholder's progress label).
        var statusText: String
        /// Relative "last active" stamp for the secondary line ("2m ago",
        /// "just now"). Empty when we have no timestamp to anchor it.
        var relativeTime: String
        /// A REAL, user-picked cwd worth surfacing, or nil. The ephemeral
        /// per-session work dir (`…/sessions/<id>/work`) is deliberately
        /// dropped — it's not a meaningful project path.
        var workingDir: String?
        var isSelected: Bool
        /// Whether the agent session is live (drives the status dot's
        /// green vs muted). Independent of `isSelected` — device bug #9:
        /// the dot used to track selection, so a second running session
        /// looked stopped. Selection is shown by the row background.
        var isRunning: Bool

        var id: String {
            switch kind {
            case .session(let id): return "real:\(id)"
            case .creatingPlaceholder(let id): return "placeholder:\(id)"
            }
        }
    }

    /// Input snapshot — what the home screen needs to know about the
    /// world to render. Built from the live SessionStore in the
    /// SwiftUI view, or constructed by tests.
    struct HomeSnapshot: Equatable {
        var harness: HomeSnapshotHarness
        var sessions: [HomeSnapshotSession]
        var placeholders: [HomeSnapshotPlaceholder]
        var selectedSessionID: String?
        var endpointDisplayHost: String?

        /// Empty/default state.
        static let empty = HomeSnapshot(
            harness: .disconnected,
            sessions: [],
            placeholders: [],
            selectedSessionID: nil,
            endpointDisplayHost: nil
        )
    }

    /// Minimal harness shape — we don't drag in HarnessState directly
    /// so the snapshot stays pure data.
    enum HomeSnapshotHarness: Equatable {
        case disconnected
        case connecting
        case live
        case reconnecting
        case failed(String)

        var canIssueCommands: Bool {
            switch self {
            case .live, .reconnecting: return true
            default: return false
            }
        }

        /// True only when the WS is actually connected. Gates the
        /// session-row dot so it can't show stale "running" green while
        /// the connection is down (device bug #30).
        var isConnected: Bool {
            if case .live = self { return true }
            return false
        }
    }

    struct HomeSnapshotSession: Equatable {
        var id: String
        var displayName: String
        var assistant: String
        var phase: String?
        /// RFC3339 last-activity / started timestamp, for the relative
        /// "last active" stamp. Optional — terminal-only sessions may
        /// not carry one yet.
        var lastActivityAt: String?
        /// A real, user-picked cwd to surface, or nil. The view layer
        /// passes nil for the ephemeral per-session work dir; we only
        /// carry a path here when it's worth showing.
        var workingDir: String?

        init(
            id: String,
            displayName: String,
            assistant: String,
            phase: String?,
            lastActivityAt: String? = nil,
            workingDir: String? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.assistant = assistant
            self.phase = phase
            self.lastActivityAt = lastActivityAt
            self.workingDir = workingDir
        }
    }

    struct HomeSnapshotPlaceholder: Equatable {
        var id: String
        var label: String
    }

    /// Computes the visible row list. Real sessions sort first, then
    /// placeholders, both in input order. `now` is injectable so the
    /// relative-time stamps are deterministic in tests.
    enum HomeViewModel {
        static func rows(_ snap: HomeSnapshot, now: Date = Date()) -> [HomeRow] {
            var rows: [HomeRow] = []
            for s in snap.sessions {
                let phase = s.phase ?? "ready"
                let isRunning = snap.harness.isConnected && !phase.hasPrefix("exited")
                rows.append(HomeRow(
                    kind: .session(id: s.id),
                    title: s.displayName,
                    agent: s.assistant,
                    statusText: statusText(phase: phase, connected: snap.harness.isConnected),
                    relativeTime: relativeTime(s.lastActivityAt, now: now),
                    workingDir: s.workingDir,
                    isSelected: snap.selectedSessionID == s.id,
                    // Green only when actually connected AND the agent
                    // hasn't exited — otherwise the dot showed stale
                    // "running" green while disconnected (device bug #30).
                    isRunning: isRunning
                ))
            }
            for p in snap.placeholders {
                rows.append(HomeRow(
                    kind: .creatingPlaceholder(id: p.id),
                    title: "Starting session…",
                    agent: "",
                    statusText: p.label,
                    relativeTime: "",
                    workingDir: nil,
                    isSelected: false,
                    isRunning: false
                ))
            }
            return rows
        }

        /// Human status word for the row's secondary line. Disconnected
        /// sessions can't be trusted as running (device bug #30) so they
        /// read "idle"; an `exited…` phase reads "exited"; otherwise
        /// "running".
        static func statusText(phase: String, connected: Bool) -> String {
            if phase.hasPrefix("exited") { return "exited" }
            if !connected { return "idle" }
            return "running"
        }

        /// Compact relative "last active" stamp ("just now", "2m ago",
        /// "3h ago", "5d ago"); older than two weeks falls back to a short
        /// date. Empty when there's no timestamp to anchor it.
        static func relativeTime(_ raw: String?, now: Date = Date()) -> String {
            guard let raw, let date = SessionNaming.parseTimestamp(raw) else { return "" }
            let delta = now.timeIntervalSince(date)
            if delta < 0 { return "just now" }
            if delta < 60 { return "just now" }
            if delta < 3600 { return "\(Int(delta / 60))m ago" }
            if delta < 86_400 { return "\(Int(delta / 3600))h ago" }
            if delta < 86_400 * 14 { return "\(Int(delta / 86_400))d ago" }
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .none
            return f.string(from: date)
        }

        /// Title shown in the empty-state when there are no rows.
        static func emptyTitle(_ snap: HomeSnapshot) -> String {
            snap.harness.canIssueCommands ? "No sessions yet" : "Waiting for server"
        }

        /// Body shown in the empty-state when there are no rows.
        static func emptyBody(_ snap: HomeSnapshot) -> String {
            snap.harness.canIssueCommands
                ? "Tap + to spin up a new conversation."
                : "Once we can reach the server, your sessions appear here."
        }

        /// SF Symbol shown in the empty-state hero.
        static func emptySymbol(_ snap: HomeSnapshot) -> String {
            snap.harness.canIssueCommands ? "sparkles" : "cloud.slash"
        }
    }
}
