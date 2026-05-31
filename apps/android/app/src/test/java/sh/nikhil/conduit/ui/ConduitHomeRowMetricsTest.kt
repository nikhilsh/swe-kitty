package sh.nikhil.conduit.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Android mirror of `apps/ios/Tests/ConduitTests/ConduitHomeRowGeometryTests.swift`.
 *
 * Pins the upstream-faithful home row metrics chosen in
 * `PLAN-CONDUIT-VISUAL-PARITY` PR 3. Before this PR the home row was
 * rendered at `titleSmall` / 16dp icon / 14dp horizontal / 12dp
 * vertical, which produced a list ~2.8× looser than upstream's actual
 * row density (audit §A.1.1 / §A.1.2). If a refactor accidentally
 * restores any of the loose values, the row stops matching upstream's
 * reference — this catches it.
 */
class ConduitHomeRowMetricsTest {

    @Test
    fun titleSizeIsFootnote() {
        assertEquals(13f, ConduitHomeRowMetrics.titlePointSize)
    }

    @Test
    fun subtitleSizeIsCaption2() {
        assertEquals(11f, ConduitHomeRowMetrics.subtitlePointSize)
    }

    @Test
    fun leadingPaddingMatchesConduit() {
        assertEquals(1f, ConduitHomeRowMetrics.leadingPadding)
        assertEquals(8f, ConduitHomeRowMetrics.trailingPadding)
    }

    @Test
    fun verticalPaddingMatchesConduit() {
        assertEquals(5f, ConduitHomeRowMetrics.verticalPadding)
    }

    @Test
    fun indicatorIsSevenDp() {
        assertEquals(7f, ConduitHomeRowMetrics.indicatorSize)
    }

    @Test
    fun activeRowFillMatchesConduit() {
        assertEquals(6f, ConduitHomeRowMetrics.activeRowCornerRadius)
        assertEquals(0.55f, ConduitHomeRowMetrics.activeRowOpacity)
    }
}
