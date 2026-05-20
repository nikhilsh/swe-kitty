import SwiftUI

/// Session "Info" screen — opened from the ⓘ button in the chat header.
///
/// Stage 2 ships a minimal placeholder so the button has a destination;
/// Stage 3 expands this with hero, agent pills, action row (Appearance /
/// Fork / Rename) and a real stats grid (messages / turns / commands /
/// files / MCP / exec time).
struct SessionInfoView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let session: ProjectSession

    var body: some View {
        NavigationStack {
            ZStack {
                SweKittyTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        statsPlaceholder
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .tint(SweKittyTheme.accentStrong)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var status: SessionStatus? { store.statusBySession[session.id] }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HealthDot(health: status?.health ?? "unknown", size: 12)
                Text(session.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SweKittyTheme.textPrimary)
                    .lineLimit(2)
                Spacer()
            }
            HStack(spacing: 8) {
                AgentPill(label: session.assistant)
                if let branch = session.branch, !branch.isEmpty {
                    AgentPill(label: branch)
                }
            }
            Text(session.id)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(SweKittyTheme.textMuted)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassRoundedRect()
    }

    private var statsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATS")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(0.9)
                .foregroundStyle(SweKittyTheme.textSecondary)
            Text("Stats grid (messages, turns, commands, files changed, MCP calls, exec time) lands in Stage 3 of the litter rebuild.")
                .font(.footnote)
                .foregroundStyle(SweKittyTheme.textMuted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassRoundedRect()
        }
    }
}

private struct AgentPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SweKittyTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassCapsule(interactive: false, tint: SweKittyTheme.accentStrong.opacity(0.22))
    }
}
