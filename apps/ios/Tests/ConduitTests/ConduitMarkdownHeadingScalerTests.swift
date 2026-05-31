import Testing
import SwiftUI
@testable import Conduit

/// Pins the heading multipliers used by `ConduitMarkdownHeadingScaler`
/// (PLAN-CONDUIT-VISUAL-PARITY PR 4, audit §A.2.2 / §B.2). Before this
/// PR our `Text(AttributedString(markdown:))` rendered `# H1` … `####
/// H4` at the body size — markdown headers produced no visual
/// hierarchy. Conduit ramps headings at 1.07× / 1.15× / 1.30× / 1.43×.
@Suite("Conduit markdown heading scale")
struct ConduitMarkdownHeadingScalerTests {

    @Test func h1MultiplierIs1_43() {
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 1) == 1.43)
    }

    @Test func h2MultiplierIs1_30() {
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 2) == 1.30)
    }

    @Test func h3MultiplierIs1_15() {
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 3) == 1.15)
    }

    @Test func h4MultiplierIs1_07() {
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 4) == 1.07)
    }

    @Test func h5AndBelowDoNotScale() {
        // Conduit's transcripts never go past h4 — h5/h6 stay at body.
        // If we ever raise the ceiling, this test catches it so the
        // size jump is intentional.
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 5) == nil)
        #expect(ConduitMarkdownHeadingScaler.multiplier(forLevel: 6) == nil)
    }

    @Test func multipliersAreMonotonicallyIncreasing() {
        // h1 > h2 > h3 > h4 — guards against accidental reorder of
        // the dictionary values.
        let m1 = ConduitMarkdownHeadingScaler.multiplier(forLevel: 1)!
        let m2 = ConduitMarkdownHeadingScaler.multiplier(forLevel: 2)!
        let m3 = ConduitMarkdownHeadingScaler.multiplier(forLevel: 3)!
        let m4 = ConduitMarkdownHeadingScaler.multiplier(forLevel: 4)!
        #expect(m1 > m2)
        #expect(m2 > m3)
        #expect(m3 > m4)
        #expect(m4 > 1.0)
    }
}
