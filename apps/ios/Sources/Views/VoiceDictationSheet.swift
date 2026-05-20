import SwiftUI

/// Global voice dictation modal — invoked from the bottom-bar mic when
/// the user is on the home view or anywhere outside a chat composer.
/// Reuses `VoiceTranscriber` (the same `SFSpeechRecognizer` pipeline
/// that powers `InlineVoiceButton`) so we don't have two competing
/// recognition stacks.
struct VoiceDictationSheet: View {
    let onTranscript: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var transcriber = VoiceTranscriber()
    @State private var captured: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                SweKittyTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 26) {
                    Spacer()
                    if case .error(let message) = transcriber.state {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(SweKittyTheme.danger)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(SweKittyTheme.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        listeningOrb
                        Text(displayTranscript.isEmpty ? "Listening…" : displayTranscript)
                            .font(.title3)
                            .foregroundStyle(SweKittyTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .frame(minHeight: 80, alignment: .top)
                    }
                    Spacer()
                    HStack(spacing: 18) {
                        Button(role: .cancel) {
                            transcriber.stop()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundStyle(SweKittyTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassRoundedRect(cornerRadius: 24)
                        }
                        .buttonStyle(.plain)

                        Button {
                            commitAndDismiss()
                        } label: {
                            Text("Send")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(SweKittyTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SweKittyTheme.accentStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(displayTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(displayTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .tint(SweKittyTheme.accentStrong)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        transcriber.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                transcriber.start { final in
                    Task { @MainActor in
                        captured = final
                    }
                }
            }
            .onDisappear { transcriber.stop() }
        }
    }

    private var displayTranscript: String {
        if !captured.isEmpty { return captured }
        return transcriber.partialTranscript
    }

    private var listeningOrb: some View {
        ZStack {
            Circle()
                .fill(SweKittyTheme.accentStrong.opacity(0.18))
                .frame(width: 140, height: 140)
                .scaleEffect(transcriber.state == .listening ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: transcriber.state)
            Circle()
                .fill(SweKittyTheme.accentStrong.opacity(0.35))
                .frame(width: 96, height: 96)
            Image(systemName: "waveform")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(SweKittyTheme.textOnAccent)
                .frame(width: 64, height: 64)
                .background(Circle().fill(SweKittyTheme.accentStrong))
        }
    }

    private func commitAndDismiss() {
        transcriber.stop()
        let text = displayTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            onTranscript(text)
        }
        dismiss()
    }
}
