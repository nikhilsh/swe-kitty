import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        @Bindable var store = store

        ZStack {
            GlassAppBackground()

            NavigationSplitView {
                ProjectListView(showSettings: $showSettings)
            } detail: {
                if let id = store.selectedSessionID,
                   let session = store.sessions.first(where: { $0.id == id }) {
                    ProjectView(session: session)
                } else {
                    ContentUnavailableView(
                        "No session selected",
                        systemImage: "terminal",
                        description: Text(detailHint)
                    )
                    .glassPane(horizontalPadding: 32, verticalPadding: 28)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .onAppear {
            // First launch: open settings if endpoint is unconfigured.
            if !store.endpoint.isComplete {
                showSettings = true
            } else if store.connection == .disconnected {
                store.connect()
            }
        }
    }

    private var detailHint: String {
        switch store.connection {
        case .disconnected: return "Open Settings to enter an endpoint and bearer token."
        case .connecting:   return "Connecting…"
        case .connected:    return "Tap + in the sidebar to start a session."
        case .failed(let e): return "Connection failed: \(e)"
        }
    }
}

struct GlassAppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.13),
                    Color(red: 0.10, green: 0.13, blue: 0.24),
                    Color(red: 0.04, green: 0.05, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.03),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.14),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassPane(horizontalPadding: CGFloat = 20, verticalPadding: CGFloat = 16) -> some View {
        self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 18, y: 12)
    }
}
