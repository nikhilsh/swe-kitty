import SwiftUI

// MARK: - LitterPillButton
//
// Capsule / circular button used for the BottomActionBar's mic / search
// (44pt) and for the centered "+" FAB which uses the brand tint.
//
// iOS 26 path uses Apple's native `.buttonStyle(.glass)` /
// `.buttonStyle(.glassProminent)` — Liquid Glass. Those styles bring
// the system-managed parts of the look that pre-26 our manual stack
// couldn't fake: specular highlights that respond to motion, content
// displacement on press, spring physics, and the dynamic light-source
// edge. Earlier our `.litterGlassCircle` only painted the glass material
// + a tint wash + a manual shadow, which gave us "blurred circle" but
// not "Apple iOS 26 button" (device feedback 2026-05-28).
//
// Pre-26 we keep the previous manual layering (solid tint UNDER the
// glass for the prominent variant + outline ring + shadow) so the
// button still reads as a clearly-filled FAB / mic / search on iOS 17–18.

extension LitterUI {

    struct PillButton: View {
        let systemImage: String
        var size: CGFloat = 44
        var tint: Color? = nil
        var isProminent: Bool = false
        let action: () -> Void

        var body: some View {
            if #available(iOS 26.0, *) {
                modernBody
            } else {
                legacyBody
            }
        }

        // MARK: iOS 26 — native Liquid Glass button

        @available(iOS 26.0, *)
        private var modernBody: some View {
            // Apple's `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`
            // own everything visual: the glass background, the press
            // animation, the specular highlight, the shape adaptation
            // (auto-rounded inside a square frame). All we feed in is
            // the glyph and the tint — `tint(_:)` colors the prominent
            // variant; the regular variant ignores it.
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: isProminent ? 22 : 18, weight: isProminent ? .bold : .semibold))
                    .frame(width: size, height: size)
            }
            .modifier(LiquidGlassButtonStyleModifier(isProminent: isProminent))
            .tint(tint ?? LitterUI.Palette.brand.color)
        }

        // MARK: pre-26 — manual glass layering

        private var legacyBody: some View {
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

/// Carries the iOS-26 `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`
/// choice. Pulling it into a `@available` modifier keeps the call sites
/// in the main view body free of `if #available` chains (Swift currently
/// won't accept the ternary `style: isProminent ? .glassProminent : .glass`
/// at the `.buttonStyle(_:)` call site because the two style structs
/// have distinct types — a single static-method `.buttonStyle(.glass)`
/// vs `.buttonStyle(.glassProminent)` is fine, a ternary across them
/// is not).
@available(iOS 26.0, *)
private struct LiquidGlassButtonStyleModifier: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
    }
}
