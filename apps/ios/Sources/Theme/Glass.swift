import SwiftUI

// MARK: - Glass effect availability wrappers
//
// Thin shims over Apple's iOS 26 Liquid Glass API (`glassEffect`,
// `GlassEffectContainer`, `glassEffectID`). On iOS 26+ each modifier
// calls the real effect; on older OSes it falls back to a tinted
// material so the layout stays recognisable. Inspired by the visual
// language of the `litter` reference app (see docs/MOBILE-PORT-MATRIX.md
// Package B sub-plan) but written against the public SwiftUI API.

struct GlassRectModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(SweKittyTheme.surfaceLight.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke((tint ?? SweKittyTheme.border).opacity(0.4), lineWidth: 1)
                )
        }
    }
}

struct GlassRoundedRectModifier: ViewModifier {
    var cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(SweKittyTheme.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct GlassCapsuleModifier: ViewModifier {
    var interactive: Bool = false
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch (tint, interactive) {
            case (let t?, true):  content.glassEffect(.regular.tint(t).interactive(), in: .capsule)
            case (let t?, false): content.glassEffect(.regular.tint(t), in: .capsule)
            case (nil, true):     content.glassEffect(.regular.interactive(), in: .capsule)
            case (nil, false):    content.glassEffect(.regular, in: .capsule)
            }
        } else {
            content
                .background(SweKittyTheme.surfaceLight)
                .clipShape(Capsule())
                .overlay(Capsule().stroke((tint ?? SweKittyTheme.border).opacity(0.4), lineWidth: 1))
        }
    }
}

struct GlassCircleModifier: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint), in: .circle)
            } else {
                content.glassEffect(.regular, in: .circle)
            }
        } else {
            content
                .background(SweKittyTheme.surfaceLight)
                .clipShape(Circle())
        }
    }
}

/// Wraps children in iOS 26's `GlassEffectContainer` so siblings marked
/// with the same `glassMorphID` morph between each other with a real
/// liquid-glass transition. Pass-through on older iOS.
struct GlassMorphContainer<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

extension View {
    func glassRect(cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius, tint: Color? = nil) -> some View {
        modifier(GlassRectModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func glassRoundedRect(cornerRadius: CGFloat = SweKittyTheme.cardCornerRadius) -> some View {
        modifier(GlassRoundedRectModifier(cornerRadius: cornerRadius))
    }

    func glassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassCapsuleModifier(interactive: interactive, tint: tint))
    }

    func glassCircle(tint: Color? = nil) -> some View {
        modifier(GlassCircleModifier(tint: tint))
    }

    /// Applies iOS 26's `glassEffectID` — which morphs glass between
    /// matched views inside a `GlassEffectContainer` — or falls back to
    /// `matchedGeometryEffect` so the frame still tweens on older iOS.
    @ViewBuilder
    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}
