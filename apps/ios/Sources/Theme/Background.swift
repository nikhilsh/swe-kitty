import SwiftUI

/// App-wide background sitting behind the navigation stack. Adapts to
/// light/dark via `SweKittyTheme.backgroundGradient`. Type name preserved
/// so existing call sites in `RootView` keep working.
struct GlassAppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SweKittyTheme.backgroundGradient(for: colorScheme)
            // Soft accent wash to give glass surfaces something to refract.
            RadialGradient(
                colors: [
                    SweKittyTheme.accentStrong.opacity(colorScheme == .dark ? 0.14 : 0.10),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    SweKittyPalette.accentStrong.color(for: colorScheme).opacity(0.08),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}
