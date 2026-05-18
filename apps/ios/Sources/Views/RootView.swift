import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        @Bindable var store = store

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
