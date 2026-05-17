import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("SweKitty")
                .font(.largeTitle.bold())
            Text("v0.0.1 — scaffold")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
