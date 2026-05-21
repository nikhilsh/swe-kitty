import SwiftUI
import UIKit

/// Stage 0 spike — placeholder host for the future Ghostty-libghostty
/// terminal view. Mounted only when `AppearanceStore
/// .experimentalNativeTerminal` is on. See
/// `docs/PLAN-TERMINAL-REWRITE.md` for the staging plan; this view's
/// purpose is to lock in the call-site shape (a SwiftUI view that
/// takes a `ProjectSession`, identical to `TerminalTabXterm`) so
/// Stage 1 can drop in the real renderer without touching
/// `ProjectView`.
///
/// The body is intentionally a static status surface — there is no
/// PTY wiring, no input routing, and no rendering yet. The xterm.js
/// path (`TerminalTabXterm`) remains the production view; toggling
/// the experimental flag off restores it.
struct GhosttyTerminalTab: View {
    // SessionStore is intentionally NOT bound at Stage 0 — the
    // placeholder view doesn't read or write session state. Stage 1
    // will add `@Environment(SessionStore.self) private var store`
    // here to wire PTY bytes through `store.terminalBuffer[session.id]`
    // and `store.sendInput`, mirroring `TerminalTabXterm`'s shape.
    let session: ProjectSession

    var body: some View {
        GhosttyTerminalView(sessionID: session.id)
            // Match TerminalTabXterm's behavior: full-bleed under the
            // home-indicator inset, but the keyboard safe area still
            // pushes the surface up so the status message stays
            // visible while the toggle is being explored on-device.
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

/// `UIViewRepresentable` wrapping a plain `UIView` that hosts the
/// Ghostty surface. For Stage 0 the surface is a placeholder
/// `UILabel`; once `ghostty-vt.xcframework` is wired (Stage 1) this
/// view grows a `ghostty_terminal_t*` and forwards keystrokes plus
/// PTY bytes.
struct GhosttyTerminalView: UIViewRepresentable {
    /// Forwarded so Stage 1 can hook up SessionStore by session ID
    /// without churn at the call site.
    let sessionID: String

    func makeUIView(context: Context) -> UIView {
        let container = GhosttyPlaceholderView(frame: .zero)
        container.backgroundColor = .black
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No-op until Stage 1 wires PTY bytes through. The placeholder
        // label is static — there is nothing to refresh.
    }
}

/// Minimal placeholder body. Lives outside `GhosttyTerminalView` so
/// snapshot testing can instantiate it without standing up a SwiftUI
/// host. Renders a centered status line on a black background — the
/// same visual idiom Ghostty's macOS shell uses for the
/// `Ghostty.App.readiness` waiting state.
final class GhosttyPlaceholderView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// First responder so the iOS keyboard appears when the user taps
    /// the surface — Stage 0 only needs the keyboard to *come up* so
    /// we can see that the input pipeline shape works. The keystrokes
    /// themselves are dropped on the floor until Stage 1.
    override var canBecomeFirstResponder: Bool { true }

    /// Placeholder accessory bar slot. Stage 1 will replace this with
    /// `TerminalAccessoryBar()` shared with `WKTerminalView`.
    override var inputAccessoryView: UIView? { nil }

    private func configure() {
        backgroundColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "GhosttyKit not yet integrated — see PLAN-TERMINAL-REWRITE Stage 0"
        label.textColor = .white
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 0
        label.textAlignment = .center
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])

        // One-tap-to-focus, matches xterm.js view's keyboard summoning
        // (xterm.js calls focus() on tap; here we route through
        // becomeFirstResponder).
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        _ = becomeFirstResponder()
    }
}
