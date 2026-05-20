import SwiftUI

/// Three-control bottom bar inspired by litter's home: mic (left),
/// large copper `+` (center), search (right). All in glass shells. The
/// `+` is the primary new-session entry point; mic + search are surface
/// affordances for the global features that arrive in Stage 5.
struct BottomActionBar: View {
    let onVoice: () -> Void
    let onPlus: () -> Void
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            actionCircle(
                icon: "mic.fill",
                accessibilityLabel: "Voice dictation",
                action: onVoice
            )
            primaryPlus
            actionCircle(
                icon: "magnifyingglass",
                accessibilityLabel: "Search sessions",
                action: onSearch
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func actionCircle(icon: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SweKittyTheme.textPrimary)
                .frame(width: 52, height: 52)
                .glassCircle(tint: SweKittyTheme.surface.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var primaryPlus: some View {
        Button(action: onPlus) {
            Image(systemName: "plus")
                .font(.title.weight(.bold))
                .foregroundStyle(SweKittyTheme.textOnAccent)
                .frame(width: 68, height: 68)
                .background(
                    Circle()
                        .fill(SweKittyTheme.accentStrong)
                        .shadow(color: SweKittyTheme.accentStrong.opacity(0.45), radius: 18, y: 8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New session")
    }
}
