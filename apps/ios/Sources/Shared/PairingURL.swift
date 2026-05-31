import Foundation

/// `conduit://host[:port]?token=<bearer>` → (endpoint URL, token).
///
/// Lived in the now-deleted `Sources/Views/SettingsSheet.swift` before
/// PR #119's cutover. Hoisted here because ConduitAddServerSheet +
/// ConduitDiscoveryView reference it from `Sources/ConduitUI/Views/`.
enum PairingURL {
    struct Parsed { let endpoint: String; let token: String }

    static func parse(_ raw: String) -> Parsed? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased() else { return nil }
        let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value ?? ""
        guard !token.isEmpty else { return nil }

        if scheme == "conduit", let host = components.host {
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
