import SwiftUI

enum ProjectTab: String, CaseIterable, Identifiable {
    case terminal, chat, browser
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .terminal: return "terminal"
        case .chat:     return "bubble.left.and.bubble.right"
        case .browser:  return "safari"
        }
    }
}

struct ProjectView: View {
    @Environment(SessionStore.self) private var store
    let session: ProjectSession

    @State private var tab: ProjectTab = .terminal
    @State private var browserMode: BrowserMode = .preview
    @State private var showInfo: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            header
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassRoundedRect()
                .clipShape(RoundedRectangle(cornerRadius: SweKittyTheme.cardCornerRadius, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 0)
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(SweKittyTheme.accentStrong)
        .sheet(isPresented: $showInfo) {
            SessionInfoView(session: session)
                .environment(store)
                .presentationDetents([.large])
        }
    }

    private var status: SessionStatus? { store.statusBySession[session.id] }
    private var lifecycle: SessionLifecycle? { store.sessionLifecycle[session.id] }

    /// Litter-style header card:
    /// Row 1: status dot · agent dropdown · spacer · refresh · info
    /// Row 2: project path (mono, muted, middle-truncated)
    /// Row 3: Terminal / Chat / Browser segmented picker (heightened — this
    ///        is the "main idea" per chat window in our app, per the plan).
    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                agentDropdown
                Spacer()
                MemoryButton(tab: $tab, mode: $browserMode)
                refreshButton
                infoButton
            }
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundStyle(SweKittyTheme.textMuted)
                Text(pathLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(SweKittyTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(SweKittyTheme.textMuted)
                }
            }
            tabPicker
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassRoundedRect()
    }

    private var pathLabel: String {
        // No first-class `cwd` on ProjectSession yet — `name` is the best
        // proxy we have. Stage 3 will surface the real cwd via the
        // SessionInfo screen + Rust core.
        session.name
    }

    private var subtitle: String {
        let parts: [String] = [
            session.branch.flatMap { $0.isEmpty ? nil : $0 } ?? "no branch",
            status?.phase ?? "ready",
            lifecycleLabel,
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    private var lifecycleLabel: String? {
        switch lifecycle {
        case .exited(let c): return "exited(\(c))"
        case .failed(let m): return m
        case .creating, .live, .none: return nil
        }
    }

    /// Row 1's main affordance: status dot + agent name + chevron, opens
    /// menu to switch agent or end the session.
    private var agentDropdown: some View {
        Menu {
            Button("Switch to Claude") { store.switchAgent(sessionID: session.id, to: "claude") }
                .disabled(session.assistant == "claude")
            Button("Switch to Codex") { store.switchAgent(sessionID: session.id, to: "codex") }
                .disabled(session.assistant == "codex")
            Divider()
            Button("End session", role: .destructive) {
                store.exit(sessionID: session.id)
            }
        } label: {
            HStack(spacing: 6) {
                HealthDot(health: status?.health ?? "unknown", size: 8)
                Text(session.assistant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassCapsule(interactive: true, tint: SweKittyTheme.accent(forAgent: session.assistant).opacity(0.32))
        }
    }

    private var refreshButton: some View {
        Button {
            store.reconnect()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SweKittyTheme.textPrimary)
                .frame(width: 32, height: 32)
                .glassCircle(tint: SweKittyTheme.surface.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reconnect")
    }

    private var infoButton: some View {
        Button {
            showInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SweKittyTheme.textPrimary)
                .frame(width: 32, height: 32)
                .glassCircle(tint: SweKittyTheme.surface.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Session info")
    }

    /// The Terminal / Chat / Browser segmented picker. Plan calls for this
    /// to be visually heightened — it's the per-session "main idea" for
    /// SweKitty (we keep it where litter only has a single chat surface).
    private var tabPicker: some View {
        Picker("View", selection: $tab) {
            ForEach(ProjectTab.allCases) { t in
                Label(t.label, systemImage: t.systemImage).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .terminal: TerminalTab(session: session)
        case .chat:     ChatTab(session: session)
        case .browser:  BrowserTab(session: session, mode: browserMode)
        }
    }
}
