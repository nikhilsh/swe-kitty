import SwiftUI

@main
struct SweKittyApp: App {
    @State private var store = SessionStore()

    init() {
        Telemetry.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
