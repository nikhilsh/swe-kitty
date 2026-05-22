import Testing
@testable import SweKitty

/// Stage 6 glass-polish — defends the per-modifier `Material` audit and
/// the per-agent tint overload. The rendering surface itself is hard to
/// snapshot in a Swift Testing run (SwiftUI / Metal), so the params are
/// lifted into a pure-data `GlassConfig` struct that we can compare
/// directly.
@Suite("GlassConfig — Stage 6 material audit + agent-tint overload")
struct GlassModifierTests {

    // MARK: - Default presets

    @Test func solidCardUsesRegularMaterial() {
        // Litter's cards feel solid, not see-through. `glassRoundedRect`
        // and `glassCapsule` must bump from `.ultraThinMaterial` /
        // `.thinMaterial` to `.regularMaterial`.
        #expect(GlassConfig.solid.material == .regular)
    }

    @Test func transientSurfaceStaysUltraThin() {
        // `glassCircle` is used for floating FAB-style controls that sit
        // over scrollable content (BottomActionBar, HomeView top icons).
        // Those should stay translucent so what's underneath remains
        // visible — `.ultraThinMaterial`.
        #expect(GlassConfig.transient.material == .ultraThin)
    }

    @Test func solidPresetHasNoAgentTintOverlay() {
        // The bare `glassRoundedRect()` must paint zero tint overlay,
        // otherwise call sites that don't pass an agent would silently
        // pick up a hue.
        #expect(GlassConfig.solid.tintOverlayOpacity == 0.0)
    }

    // MARK: - Agent-tint overload

    @Test func agentTintedConfigDiffersFromBare() {
        // The headline assertion for this stage: passing an
        // `agentTint:` overload must produce a different `GlassConfig`
        // than the bare overload — otherwise the overlay isn't being
        // applied and call sites that switched to the agent-aware
        // overload regress to a flat card.
        let bare = GlassConfig.solid
        let tinted = GlassConfig.solidAgentTinted()
        #expect(bare != tinted)
    }

    @Test func agentTintedOverlayIsSubtle() {
        // Spec says 0.08 opacity — light enough that the underlying
        // material still reads as the dominant surface, dark enough
        // that the agent hue is visible against the gradient highlight.
        #expect(GlassConfig.solidAgentTinted().tintOverlayOpacity == 0.08)
    }

    @Test func agentTintedKeepsRegularMaterial() {
        // The tint is a layer on top, not a swap of the material. The
        // tinted variant must keep `.regularMaterial` so the visual
        // weight of the card matches the un-tinted siblings on the
        // same screen (e.g. SessionInfoView's hero + server-usage
        // cards should feel like one set, not two).
        #expect(GlassConfig.solidAgentTinted().material == .regular)
    }

    @Test func agentTintedOpacityIsConfigurable() {
        // Optional override — Stage 6 also wants to experiment with
        // 0.04 for tool/diff cards in ConversationView. Verify the
        // helper takes an explicit opacity.
        let cfg = GlassConfig.solidAgentTinted(opacity: 0.04)
        #expect(cfg.tintOverlayOpacity == 0.04)
        #expect(cfg.material == .regular)
    }
}
