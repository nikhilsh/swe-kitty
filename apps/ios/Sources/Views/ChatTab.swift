import SwiftUI

/// v1 stub. Full structured-message UI lands in task 007 (multi-view).
struct ChatTab: View {
    @Environment(SessionStore.self) private var store
    let session: ProjectSession

    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, ev in
                        ChatRow(event: ev)
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("Message agent…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    let msg = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !msg.isEmpty else { return }
                    store.sendChat(sessionID: session.id, message: msg)
                    draft = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)
        }
    }

    private var events: [ChatEvent] { store.chatLog[session.id] ?? [] }
}

private struct ChatRow: View {
    let event: ChatEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.role.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(event.content)
                .font(.callout)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
