import SwiftUI

extension ConduitUI {
    /// The Conduit brand mark (the terminal-daemon `ConduitMark`) with a
    /// subtle, continuous "breathe" — a gentle scale loop so the home header
    /// feels alive without the attention-grabbing pulse of the cold-start
    /// splash. Mirrors the Android `AnimatedBrandMark`; both share the same
    /// calm timing (1.0 → 1.03 over 2.2s, ease-in-out, autoreversing).
    ///
    /// Distinct on purpose from `AnimatedSplashView`'s faster 1.2s
    /// "loading" pulse — the splash signals work-in-progress, the header
    /// just breathes.
    struct AnimatedBrandMark: View {
        var size: CGFloat = 32
        @State private var breathing = false

        var body: some View {
            ConduitUI.ConduitMark(size: size)
                .scaleEffect(breathing ? 1.03 : 1.0)
                .animation(
                    .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: breathing
                )
                .onAppear { breathing = true }
        }
    }
}
