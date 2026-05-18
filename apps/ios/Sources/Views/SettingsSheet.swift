import SwiftUI

/// v1: manual endpoint + bearer token entry. Replaced by QR + mDNS in task 009.
struct SettingsSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var url: String = ""
    @State private var token: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("ws://192.168.1.10:1977", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Bearer token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Save & Connect") {
                        store.endpoint = StoredEndpoint(url: url.trimmingCharacters(in: .whitespaces),
                                                        token: token.trimmingCharacters(in: .whitespaces))
                        store.disconnect()
                        store.connect()
                        dismiss()
                    }
                    .disabled(url.isEmpty || token.isEmpty)
                }
                Section("Status") {
                    LabeledContent("Connection") {
                        Text(connectionLabel).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                url = store.endpoint.url
                token = store.endpoint.token
            }
        }
    }

    private var connectionLabel: String {
        switch store.connection {
        case .disconnected:  return "Disconnected"
        case .connecting:    return "Connecting…"
        case .connected:     return "Connected"
        case .failed(let e): return "Failed: \(e)"
        }
    }
}
