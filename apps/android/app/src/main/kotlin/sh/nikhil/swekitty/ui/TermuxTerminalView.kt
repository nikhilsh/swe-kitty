package sh.nikhil.swekitty.ui

import android.content.Context
import android.graphics.Color as AndroidColor
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ProjectSession

/**
 * Android mirror of iOS [GhosttyTerminalView] (PR #57). Stage 0 of the
 * terminal-renderer rewrite — see `docs/PLAN-TERMINAL-REWRITE.md`
 * (Android section). At this stage there is no Termux dependency yet
 * (that arrives in Stage 1 along with `com.termux:terminal-view`); we
 * only prove the wiring shape:
 *
 *  - flag-gated `AndroidView` slot in [TerminalPage]
 *  - placeholder `View` with a black background + status text
 *  - no PTY wiring, no input routing, no rendering
 *
 * Toggling [sh.nikhil.swekitty.AppearanceStore.experimentalNativeTerminal]
 * off restores the production xterm.js path ([WebTerminal]) within one
 * Compose recomposition — identical rollback shape to iOS.
 */
@Composable
fun TermuxTerminalView(
    @Suppress("UNUSED_PARAMETER") store: SessionStore,
    @Suppress("UNUSED_PARAMETER") session: ProjectSession,
    modifier: Modifier = Modifier,
) {
    AndroidView(
        modifier = modifier,
        factory = { ctx -> TermuxPlaceholderView(ctx) },
        update = {
            // No-op until Stage 1 wires PTY bytes from
            // store.terminalBuffer[session.id] into a real
            // com.termux.view.TerminalView via TerminalSession.write.
        },
    )
}

/**
 * Plain `FrameLayout` hosting a centered status label on a black
 * background — same visual idiom iOS Stage 0 used for
 * `GhosttyPlaceholderView`. Lives outside [TermuxTerminalView] so a
 * future Roborazzi snapshot can instantiate it without standing up a
 * Compose host.
 */
internal class TermuxPlaceholderView(context: Context) : FrameLayout(context) {
    init {
        setBackgroundColor(AndroidColor.BLACK)
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )

        val label = TextView(context).apply {
            text = "Termux Stage 0 mounted — see PLAN-TERMINAL-REWRITE Android section"
            setTextColor(AndroidColor.WHITE)
            textSize = 13f
            gravity = Gravity.CENTER
            // Mono font matches the eventual TerminalView aesthetic
            // and is consistent with the iOS Stage 0 placeholder.
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(48, 24, 48, 24)
        }
        val lp = LayoutParams(
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
        ).apply { gravity = Gravity.CENTER }
        addView(label, lp)
    }

    /**
     * One-tap focus so a future Stage 2 keystroke wiring can summon
     * the IME the same way [WebTerminal] does on tap. Stage 0 still
     * drops keystrokes on the floor.
     */
    override fun onTouchEvent(event: android.view.MotionEvent): Boolean {
        if (event.action == android.view.MotionEvent.ACTION_UP) {
            requestFocus()
            performClick()
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
