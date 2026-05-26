import SwiftUI

// MARK: - LitterPillButton
//
// Capsule-shaped button — used for the BottomActionBar's mic / search
// (44x44 floating glass capsules) and for the centered "+" FAB which
// is sized larger and uses the brand tint.

extension LitterUI {

    struct PillButton: View {
        let systemImage: String
        var size: CGFloat = 44
        var tint: Color? = nil
        var isProminent: Bool = false
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: isProminent ? 22 : 18, weight: isProminent ? .bold : .semibold))
                    .foregroundStyle(foreground)
                    .frame(width: size, height: size)
                    // device feedback (v0.0.47): the prominent "+" read as a
                    // faint outline. `litterGlassCircle` only paints the tint
                    // as a ~6% wash over translucent glass, so a brand-tinted
                    // FAB never actually filled. Lay a SOLID brand circle
                    // UNDER the glass for the prominent variant so the create
                    // affordance reads as a clearly-filled copper button with
                    // a contrasting glyph; mic/search stay on plain glass.
                    .background {
                        if isProminent {
                            Circle()
                                .fill(tint ?? LitterUI.Palette.brand.color)
                        }
                    }
                    .litterGlassCircle(
                        tint: backgroundTint,
                        config: .floating
                    )
                    // Subtle brand-tinted ring + lift so the filled FAB
                    // separates from the surface behind it.
                    .overlay {
                        if isProminent {
                            Circle()
                                .strokeBorder(
                                    LitterUI.Palette.textOnAccent.color.opacity(0.22),
                                    lineWidth: 1
                                )
                        }
                    }
                    .shadow(
                        color: isProminent
                            ? (tint ?? LitterUI.Palette.brand.color).opacity(0.45)
                            : .clear,
                        radius: isProminent ? 10 : 0,
                        x: 0,
                        y: isProminent ? 4 : 0
                    )
            }
            .buttonStyle(.plain)
        }

        private var backgroundTint: Color {
            isProminent ? (tint ?? LitterUI.Palette.brand.color) : (tint ?? LitterUI.Palette.surfaceLight.color)
        }

        private var foreground: Color {
            isProminent
                ? LitterUI.Palette.textOnAccent.color
                : LitterUI.Palette.textPrimary.color
        }
    }
}
