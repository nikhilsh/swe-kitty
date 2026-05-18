import SwiftUI

struct ChatTab: View {
    @Environment(SessionStore.self) private var store
    let session: ProjectSession

    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(events.enumerated()), id: \.offset) { idx, ev in
                            ChatRow(event: ev).id(idx)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: events.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
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
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2)
                Text(event.role.uppercased()).font(.caption2.bold())
                if !event.ts.isEmpty {
                    Text(event.ts).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.secondary)

            Text(event.content)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: bubbleAlignment)

            if !event.files.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(event.files.enumerated()), id: \.offset) { _, f in
                        HStack(spacing: 4) {
                            Image(systemName: "doc")
                            Text(f.path).font(.caption.monospaced())
                            if !f.rev.isEmpty {
                                Text("@\(f.rev.prefix(7))")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alignment: HorizontalAlignment {
        event.role == "user" ? .trailing : .leading
    }
    private var bubbleAlignment: Alignment {
        event.role == "user" ? .trailing : .leading
    }
    private var bubbleColor: Color {
        switch event.role {
        case "user":      return Color.accentColor.opacity(0.18)
        case "assistant": return Color.gray.opacity(0.12)
        case "tool":      return Color.orange.opacity(0.12)
        default:          return Color.gray.opacity(0.08)
        }
    }
    private var textColor: Color { .primary }
    private var icon: String {
        switch event.role {
        case "user":      return "person.fill"
        case "assistant": return "cpu"
        case "tool":      return "wrench.and.screwdriver"
        default:          return "bubble.left"
        }
    }
}
