import SwiftUI
import WebKit

/// v1 stub. Real per-session preview proxy plumbing lands in task 007.
struct BrowserTab: View {
    @Environment(SessionStore.self) private var store
    let session: ProjectSession

    var body: some View {
        Group {
            if let url = previewURL {
                WebView(url: url)
            } else {
                ContentUnavailableView(
                    "No preview yet",
                    systemImage: "safari",
                    description: Text("The agent hasn't reported a preview URL for this session.")
                )
            }
        }
    }

    private var previewURL: URL? {
        if let p = store.preview[session.id] { return URL(string: p.url) }
        return nil
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
