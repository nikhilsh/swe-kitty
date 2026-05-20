import SwiftUI

/// Settings — sectioned IA matching the litter reference: Support /
/// Appearance / Font / Conversation / Servers / Harness / About /
/// Experimental. The big pairing form is gone — adding a server (any of
/// QR / mDNS / SSH / manual) goes through [`AddServerSheet`].
struct SettingsSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var showAddServer = false
    @State private var showAppearance = false

    private let sponsorURL = URL(string: "https://github.com/sponsors/nikhilsh")!

    var body: some View {
        NavigationStack {
            ZStack {
                SweKittyTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        supportSection
                        appearanceSection
                        fontSection
                        conversationSection
                        serversSection
                        harnessSection
                        aboutSection
                        experimentalSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(SweKittyTheme.accentStrong)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddServer) {
                AddServerSheet()
                    .environment(store)
            }
            .sheet(isPresented: $showAppearance) {
                AppearanceSheet()
                    .environment(appearance)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsRow(
                icon: "heart.fill",
                title: "Sponsor on GitHub",
                subtitle: "Help fund continued development"
            ) {
                openURL(sponsorURL)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            SettingsRow(
                icon: "paintpalette.fill",
                title: "Theme",
                subtitle: appearance.themeMode.label
            ) {
                showAppearance = true
            }
        }
    }

    private var fontSection: some View {
        SettingsSection(title: "Font") {
            @Bindable var bindable = appearance
            ForEach(Array(AppearanceStore.FontFamily.allCases.enumerated()), id: \.element.id) { idx, choice in
                SettingsPickerRow(
                    icon: choice == .monospaced ? "chevron.left.forwardslash.chevron.right" : "textformat",
                    title: choice.label,
                    isSelected: appearance.fontFamily == choice
                ) {
                    bindable.fontFamily = choice
                }
                if idx < AppearanceStore.FontFamily.allCases.count - 1 {
                    Divider().background(SweKittyTheme.separator)
                }
            }
        }
    }

    private var conversationSection: some View {
        SettingsSection(title: "Conversation") {
            @Bindable var bindable = appearance
            SettingsToggleRow(
                icon: "rectangle.compress.vertical",
                title: "Collapse Turns",
                subtitle: "Show only summaries; tap to expand",
                isOn: $bindable.collapseTurns
            )
        }
    }

    @ViewBuilder
    private var serversSection: some View {
        SettingsSection(title: "Servers") {
            if !store.savedServers.isEmpty {
                ForEach(Array(store.savedServers.enumerated()), id: \.element.id) { idx, server in
                    ServerListRow(server: server, store: store)
                    if idx < store.savedServers.count - 1 {
                        Divider().background(SweKittyTheme.separator)
                    }
                }
                Divider().background(SweKittyTheme.separator)
            }
            SettingsRow(
                icon: "plus.circle.fill",
                title: "Add server",
                subtitle: "QR · LAN discover · SSH · paste URL+token"
            ) {
                showAddServer = true
            }
        }
    }

    @ViewBuilder
    private var harnessSection: some View {
        if store.endpoint.isComplete {
            SettingsSection(title: "Harness") {
                HStack {
                    Image(systemName: "link")
                        .frame(width: 22)
                        .foregroundStyle(SweKittyTheme.accentStrong)
                    Text("Link")
                        .foregroundStyle(SweKittyTheme.textBody)
                    Spacer()
                    HarnessBadge(state: store.harness)
                }
                if let reason = store.harness.failureReason {
                    Divider().background(SweKittyTheme.separator)
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(SweKittyTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if shouldShowReconnect {
                    Divider().background(SweKittyTheme.separator)
                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: "Reconnect",
                        subtitle: nil
                    ) {
                        store.reconnect()
                    }
                }
                Divider().background(SweKittyTheme.separator)
                SettingsRow(
                    icon: "trash",
                    title: "Forget harness",
                    subtitle: store.endpoint.displayHost,
                    iconTint: SweKittyTheme.danger,
                    titleTint: SweKittyTheme.danger
                ) {
                    store.endpoint = .empty
                    store.disconnect()
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            HStack {
                Image(systemName: "app.fill")
                    .frame(width: 22)
                    .foregroundStyle(SweKittyTheme.accentStrong)
                Text("App")
                    .foregroundStyle(SweKittyTheme.textBody)
                Spacer()
                Text("SweKitty")
                    .foregroundStyle(SweKittyTheme.textSecondary)
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Divider().background(SweKittyTheme.separator)
                HStack {
                    Image(systemName: "number")
                        .frame(width: 22)
                        .foregroundStyle(SweKittyTheme.accentStrong)
                    Text("Version")
                        .foregroundStyle(SweKittyTheme.textBody)
                    Spacer()
                    Text(version)
                        .foregroundStyle(SweKittyTheme.textSecondary)
                }
            }
        }
    }

    private var experimentalSection: some View {
        SettingsSection(title: "Experimental") {
            Text("Voice dictation and debug flags arrive in a later stage of the litter rebuild.")
                .font(.footnote)
                .foregroundStyle(SweKittyTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Only show the manual Reconnect affordance when the link
    /// actually needs intervention.
    private var shouldShowReconnect: Bool {
        guard store.endpoint.isComplete else { return false }
        switch store.harness {
        case .disconnected, .failed: return true
        default: return false
        }
    }
}

/// `swekitty://host[:port]?token=<bearer>` → (endpoint URL, token).
enum PairingURL {
    struct Parsed { let endpoint: String; let token: String }

    static func parse(_ raw: String) -> Parsed? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased() else { return nil }
        let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value ?? ""
        guard !token.isEmpty else { return nil }

        if scheme == "swekitty", let host = components.host {
            let port = components.port.map { ":\($0)" } ?? ""
            return Parsed(endpoint: "ws://\(host)\(port)", token: token)
        }

        if (scheme == "ws" || scheme == "wss"),
           let host = components.host {
            let port = components.port.map { ":\($0)" } ?? ""
            return Parsed(endpoint: "\(scheme)://\(host)\(port)", token: token)
        }
        return nil
    }
}

// MARK: - Building blocks

/// Section: small uppercased mono label + a glass card containing rows.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(0.9)
                .foregroundStyle(SweKittyTheme.textSecondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassRoundedRect()
        }
    }
}

/// Tap-to-perform row: copper icon · title (+ optional subtitle) · chevron.
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconTint: Color = SweKittyTheme.accentStrong
    var titleTint: Color = SweKittyTheme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 22)
                    .foregroundStyle(iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleTint)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(SweKittyTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Toggle row: copper icon · title/subtitle · trailing Switch.
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 22)
                .foregroundStyle(SweKittyTheme.accentStrong)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(SweKittyTheme.textMuted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SweKittyTheme.accentStrong)
        }
    }
}

/// Radio-style picker row used by the inline Font section.
struct SettingsPickerRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 22)
                    .foregroundStyle(SweKittyTheme.accentStrong)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? SweKittyTheme.accentStrong : SweKittyTheme.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Single row in the Servers section: name, host, Default badge, Use,
/// trash. The previous implementation lived inline in `savedServersCard`.
private struct ServerListRow: View {
    let server: SavedServer
    let store: SessionStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.body)
                .frame(width: 22)
                .foregroundStyle(SweKittyTheme.accentStrong)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textPrimary)
                Text(server.endpoint.displayHost)
                    .font(.caption)
                    .foregroundStyle(SweKittyTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if server.isDefault {
                Text("Default")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .glassCapsule(interactive: false, tint: SweKittyTheme.accentStrong.opacity(0.22))
            }
            Button("Use") {
                store.selectSavedServer(server.id, autoConnect: true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SweKittyTheme.accentStrong)
            Button(role: .destructive) {
                store.removeSavedServer(server.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}
