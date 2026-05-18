import SwiftUI

struct ProjectListView: View {
    @Environment(SessionStore.self) private var store
    @Binding var showSettings: Bool

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedSessionID) {
            Section("Sessions") {
                if store.sessions.isEmpty {
                    Text("No sessions yet").foregroundStyle(.secondary)
                } else {
                    ForEach(store.sessions, id: \.id) { session in
                        SessionRow(session: session,
                                   status: store.statusBySession[session.id])
                            .tag(session.id as String?)
                    }
                }
            }
        }
        .navigationTitle("SweKitty")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Claude") { store.createSession(assistant: "claude") }
                    Button("Codex")  { store.createSession(assistant: "codex") }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(store.connection != .connected)
            }
            ToolbarItem(placement: .bottomBar) {
                ConnectionBadge()
            }
        }
    }
}

private struct SessionRow: View {
    let session: ProjectSession
    let status: SessionStatus?

    var body: some View {
        HStack(spacing: 8) {
            HealthDot(health: status?.health ?? "unknown")
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.body)
                Text("\(session.assistant) · \(session.branch ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HealthDot: View {
    let health: String
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityLabel("health: \(health)")
    }
    private var color: Color {
        switch health {
        case "green":  return .green
        case "yellow": return .yellow
        case "red":    return .red
        default:       return .gray
        }
    }
}

private struct ConnectionBadge: View {
    @Environment(SessionStore.self) private var store
    var body: some View {
        switch store.connection {
        case .disconnected:
            Button("Connect") { store.connect() }
                .disabled(!store.endpoint.isComplete)
        case .connecting:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Connecting…") }
        case .connected:
            Label("Connected", systemImage: "dot.radiowaves.left.and.right")
                .foregroundStyle(.green)
        case .failed(let e):
            Label(e, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
