import SwiftUI

// MARK: - Glass effect wrappers
//
// The previous pass tried to use unreleased Liquid Glass-specific SwiftUI
// symbols that are not present in the runner SDK yet. Keep the same visual
// direction, but implement it with compile-safe material layering so CI and
// release builds stay shippable.
//
// Stage 6 polish (litter):
//   - Each modifier's `Material` is chosen by intent rather than uniformly
//     `.thinMaterial`. Solid cards (`glassRoundedRect`, `glassCapsule`)
//     use `.regularMaterial` so they read closer to litter's chunky
//     surfaces; transient affordances (`glassCircle` for floating FAB-ish
//     buttons) stay on `.ultraThinMaterial` so they melt into whatever
//     scrolls underneath.
//   - `glassRoundedRect(agentTint:)` overlays the per-agent accent at
//     0.08 opacity on top of the material — same shape as the bare
//     overload, just a faint hue.

/// Pure-data summary of a glass surface's tunables. Used directly by the
/// rendering modifiers, and exposed so the test suite can compare
/// configurations without running SwiftUI.
struct GlassConfig: Equatable {
    var material: GlassMaterial
    var highlightOpacity: Double
    var shadowOpacity: Double
    var tintOverlayOpacity: Double

    /// Default for solid card surfaces (`glassRoundedRect`, `glassCapsule`).
    static let solid = GlassConfig(
        material: .regular,
        highlightOpacity: 0.24,
        shadowOpacity: 0.16,
        tintOverlayOpacity: 0.0
    )

    /// Default for transient / floating surfaces (`glassCircle`).
    static let transient = GlassConfig(
        material: .ultraThin,
        highlightOpacity: 0.28,
        shadowOpacity: 0.16,
        tintOverlayOpacity: 0.0
    )

    /// Solid card with a per-agent tint overlay (8% opacity of the
    /// agent accent painted over the material).
    static func solidAgentTinted(opacity: Double = 0.08) -> GlassConfig {
        GlassConfig(
            material: .regular,
            highlightOpacity: 0.24,
            shadowOpacity: 0.16,
            tintOverlayOpacity: opacity
        )
    }
}

/// Material enum the rendering layer maps to SwiftUI's `Material`. Kept
/// separate so `GlassConfig` stays `Equatable` and unit-testable.
enum GlassMaterial: Equatable {
    case regular
    case thin
    case ultraThin

    var swiftUIMaterial: Material {
        switch self {
        case .regular:   return .regularMaterial
        case .thin:      return .thinMaterial
        case .ultraThin: return .ultraThinMaterial
        }
    }
}

private struct GlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Color?
    var config: GlassConfig = .solid

    func body(content: Content) -> some View {
        let stroke = (tint ?? SweKittyTheme.border).opacity(0.42)
        let glow = (tint ?? SweKittyTheme.accentStrong).opacity(config.highlightOpacity)

        content
            .background {
                shape
                    .fill(config.material.swiftUIMaterial)
                    .overlay {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        glow,
                                        SweKittyTheme.surfaceLight.opacity(0.06),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        // Per-agent tint overlay — flat fill at a low
                        // opacity so the card picks up the agent hue
                        // without drowning out the underlying material.
                        if let tint, config.tintOverlayOpacity > 0 {
                            shape.fill(tint.opacity(config.tintOverlayOpacity))
                        }
                    }
            }
            .overlay {
                shape
                    .stroke(stroke, lineWidth: 1)
            }
            .clipShape(shape)
            .shadow(color: SweKittyTheme.textPrimary.opacity(config.shadowOpacity), radius: 18, x: 0, y: 10)
    }
}

struct GlassRectModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        content.modifier(
            GlassSurfaceModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                config: .solid
            )
        )
    }
}

struct GlassRoundedRectModifier: ViewModifier {
    var cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius
    var agentTint: Color? = nil

    func body(content: Content) -> some View {
        content.modifier(
            GlassSurfaceModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: agentTint,
                config: agentTint == nil ? .solid : .solidAgentTinted()
            )
        )
    }
}

struct GlassCapsuleModifier: ViewModifier {
    var interactive: Bool = false
    var tint: Color?

    func body(content: Content) -> some View {
        var config = GlassConfig.solid
        config.highlightOpacity = interactive ? 0.34 : 0.22
        config.shadowOpacity = interactive ? 0.22 : 0.14
        return content
            .modifier(
                GlassSurfaceModifier(
                    shape: Capsule(),
                    tint: tint,
                    config: config
                )
            )
            .scaleEffect(interactive ? 1.0 : 0.995)
    }
}

struct GlassCircleModifier: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        content.modifier(
            GlassSurfaceModifier(
                shape: Circle(),
                tint: tint,
                config: .transient
            )
        )
    }
}

/// Future shell rewrites can replace this with platform-native morphing
/// once the SDK is available in CI. For now it is a pass-through wrapper.
struct GlassMorphContainer<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
    }
}

extension View {
    func glassRect(cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius, tint: Color? = nil) -> some View {
        modifier(GlassRectModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func glassRoundedRect(cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius) -> some View {
        modifier(GlassRoundedRectModifier(cornerRadius: cornerRadius))
    }

    /// Agent-tinted overload: same surface as `glassRoundedRect`, plus a
    /// flat 8% overlay of the agent accent so cards in a session pick
    /// up the agent hue without the heavy capsule tint.
    func glassRoundedRect(cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius, agentTint: Color) -> some View {
        modifier(GlassRoundedRectModifier(cornerRadius: cornerRadius, agentTint: agentTint))
    }

    func glassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassCapsuleModifier(interactive: interactive, tint: tint))
    }

    func glassCircle(tint: Color? = nil) -> some View {
        modifier(GlassCircleModifier(tint: tint))
    }

    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        matchedGeometryEffect(id: id, in: namespace)
    }
}
