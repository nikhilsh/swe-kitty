import SwiftUI

struct ChatTab: View {
    @Environment(SessionStore.self) private var store
    let session: ProjectSession

    @State private var draft: String = ""
    @State private var autoFollow = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if events.isEmpty {
                            emptyState
                        } else {
                            ConversationTimelineView(events: events)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in autoFollow = false }
                )
                .onChange(of: events.count) { _, _ in
                    guard autoFollow else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !autoFollow && !events.isEmpty {
                    Button {
                        autoFollow = true
                    } label: {
                        Label("Latest", systemImage: "arrow.down")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .glassCapsule(interactive: true, tint: SweKittyTheme.accentStrong.opacity(0.28))
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
                }
            }
            Divider().background(SweKittyTheme.separator)
            composer
                .padding(10)
        }
    }

    private var events: [ChatEvent] { store.chatLog[session.id] ?? [] }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No conversation yet")
                .font(.headline)
                .foregroundStyle(SweKittyTheme.textPrimary)
            Text("Messages, tool activity, diffs, and file references will appear here once the session starts responding.")
                .font(.subheadline)
                .foregroundStyle(SweKittyTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .glassRect(cornerRadius: 18, tint: SweKittyTheme.accentStrong.opacity(0.16))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "message.badge.waveform")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.accentStrong)
                Text("Reply")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SweKittyTheme.textSecondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message agent…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SweKittyTheme.surface.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    let msg = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !msg.isEmpty else { return }
                    store.sendChat(sessionID: session.id, message: msg)
                    draft = ""
                    autoFollow = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SweKittyTheme.textOnAccent)
                        .frame(width: 42, height: 42)
                        .background(SweKittyTheme.accentStrong)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassRoundedRect(cornerRadius: 20)
    }
}
