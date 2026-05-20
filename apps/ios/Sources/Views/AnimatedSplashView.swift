import SwiftUI

/// Brief launch splash. Shows the app mark over the standard
/// background gradient with a soft spring-in, holds, then fades out
/// over ~1.2s total. Mirrors the Android `AnimatedSplash.kt`.
///
/// Wired in `SweKittyApp` as an overlay on top of `RootView` so the
/// real UI is mounted underneath and ready by the time the splash
/// fades — no blank window once the splash dismisses.
struct AnimatedSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onFinish: () -> Void

    @State private var entered: Bool = false
    @State private var visible: Bool = true

    var body: some View {
        ZStack {
            SweKittyTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundStyle(SweKittyTheme.accentStrong)
                    .shadow(color: SweKittyTheme.accentStrong.opacity(0.35), radius: 22, x: 0, y: 10)
                Text("SweKitty")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(SweKittyTheme.textPrimary)
            }
            .scaleEffect(entered ? 1.0 : 0.85)
            .opacity(visible ? 1.0 : 0.0)
        }
        .onAppear { runSequence() }
        .allowsHitTesting(false)
    }

    private func runSequence() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            entered = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.35)) {
                visible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                onFinish()
            }
        }
    }
}
