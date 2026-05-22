package sh.nikhil.swekitty.ui

import android.content.Context
import android.graphics.Color as AndroidColor
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.termux.terminal.TerminalSession
import com.termux.terminal.TerminalSessionClient
import com.termux.view.TerminalView
import com.termux.view.TerminalViewClient
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ProjectSession

/**
 * Android mirror of iOS [GhosttyTerminalView]. Stage 1 of the
 * terminal-renderer rewrite — see `docs/PLAN-TERMINAL-REWRITE.md`
 * (Android section, "Stage 1 — broker byte stream → TerminalSession").
 *
 * Stage 1 deliverable: a real `com.termux.view.TerminalView` mounts
 * inside the existing Compose `AndroidView` slot, with a hardcoded
 * "Stage 1 mounted via Termux\n" banner so we can eyeball that the
 * Maven dep linked + the native View renders. PTY byte-stream wiring
 * (broker → `TerminalSession.write`, `onSizeChanged` → broker resize)
 * is intentionally deferred to Stage 2 — same shape iOS Stage 1 used
 * with `GhosttyTerminalView`.
 *
 * Risk mitigation: the entire factory body is wrapped in a try/catch.
 * If the Termux Maven dep ever fails to resolve, or `TerminalSession`'s
 * JNI `createSubprocess` throws on a hardened device, the wrapper
 * falls back to [TermuxPlaceholderView] (the Stage 0 placeholder) so
 * the Android build still works. We log the exception via [Log.w]
 * with a tag the catcher can grep in `adb logcat` to know which path
 * is live.
 *
 * Toggling [sh.nikhil.swekitty.AppearanceStore.experimentalNativeTerminal]
 * off restores the production xterm.js path ([WebTerminal]) within one
 * Compose recomposition — identical rollback shape to iOS.
 */
@Composable
fun TermuxTerminalView(
    @Suppress("UNUSED_PARAMETER") store: SessionStore,
    session: ProjectSession,
    modifier: Modifier = Modifier,
) {
    val config = TermuxSessionConfig.from(session)
    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            try {
                buildTermuxTerminalView(ctx, config)
            } catch (t: Throwable) {
                // Catch Errors too (e.g. NoClassDefFoundError if the
                // JitPack dep didn't resolve at runtime on some
                // device). Either way, the Stage 0 placeholder is the
                // safe fallback — the user still sees a black-bg
                // status surface and the rest of the app stays alive.
                Log.w(TAG, "TerminalView mount failed; falling back to placeholder", t)
                TermuxPlaceholderView(ctx)
            }
        },
        update = {
            // Stage 1 has no PTY wiring; the hardcoded banner is
            // written once in the factory. Stage 2 will diff
            // store.terminalBuffer[session.id] here and forward new
            // bytes via session.write / emulator.append, mirroring
            // WebTerminal.kt's `lastFedByteCount` pattern.
        },
    )
}

private const val TAG = "TermuxTerminalView"

/**
 * Stage 1 banner — written into the emulator on mount so the screen
 * isn't blank while the (real) shell warms up. Mirrors the iOS Stage 1
 * "GhosttyVT linked" debug print.
 */
private const val STAGE1_BANNER = "Stage 1 mounted via Termux\r\n"

/**
 * Build the live [TerminalView] hosting a Termux [TerminalSession].
 *
 * Kept as a top-level function so it can be unit-tested separately
 * once Stage 2 lands input wiring (we'll lift the body and inject a
 * fake `TerminalView` factory). Today's call sites: the factory above
 * and any future Roborazzi snapshot that wants to render the live
 * surface instead of the placeholder.
 */
private fun buildTermuxTerminalView(
    ctx: Context,
    config: TermuxSessionConfig,
): View {
    val view = TerminalView(ctx, /* attributes= */ null).apply {
        setBackgroundColor(AndroidColor.BLACK)
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        // The client is required for hardware keys + IME + selection.
        // Stage 1 only needs the no-op shape; Stage 2 will replace
        // this with a real implementation backed by SessionStore.
        setTerminalViewClient(NoopTerminalViewClient)
    }

    val session = TerminalSession(
        /* shellPath = */ config.shellPath,
        /* cwd = */ config.cwd,
        /* args = */ config.args,
        /* env = */ config.env,
        /* transcriptRows = */ TermuxSessionConfig.TRANSCRIPT_ROWS,
        /* client = */ NoopTerminalSessionClient,
    )
    view.attachSession(session)

    // Inject the Stage 1 banner. `emulator` is null until
    // updateSize/initializeEmulator runs — which happens on the first
    // layout pass. Defer the append until then so we don't NPE.
    view.post {
        try {
            val bytes = STAGE1_BANNER.toByteArray(Charsets.UTF_8)
            val emulator = session.emulator
            emulator?.append(bytes, bytes.size)
        } catch (t: Throwable) {
            Log.w(TAG, "Stage 1 banner inject failed", t)
        }
    }

    return view
}

/**
 * Plain-data Stage 1 plumbing helper. Lifted out of the Compose
 * function so [buildTermuxTerminalView] is testable without standing
 * up an Android Context, and so the Stage 2 patch only has to swap
 * the construction-site fields (shell path, env) — not the wiring.
 *
 * The defaults below assume the Android shell process for the local-
 * preview path. In Stage 2 the broker-attached path will likely pass
 * a `/system/bin/sh -c "cat"` style sink (or no subprocess at all,
 * once we factor out the JNI dependency) — kept here as a single
 * source of truth so that decision is local.
 */
internal data class TermuxSessionConfig(
    val shellPath: String,
    val cwd: String,
    val args: Array<String>,
    val env: Array<String>,
) {
    companion object {
        // Termux's default; large enough to hold a typical session's
        // history without paging. The WebTerminal path keeps its own
        // ring in SessionStore.terminalBuffer; once Stage 2 wires the
        // two together we'll bound this by the broker's ring size.
        const val TRANSCRIPT_ROWS = 2_000

        /**
         * Build the Stage 1 config from a [ProjectSession]. Pure
         * function for unit-testability. Stage 1 ignores
         * `session.id` — the Termux session here is local-only and
         * disconnected from broker bytes. Stage 2 will keep this
         * factory but route the resulting session through
         * `SessionStore.terminalBuffer[session.id]`.
         */
        fun from(@Suppress("UNUSED_PARAMETER") session: ProjectSession): TermuxSessionConfig {
            return TermuxSessionConfig(
                // `/system/bin/sh` exists on every Android device
                // since API 1; safe default for the Stage 1 mount-
                // only smoke test. Termux's own app uses
                // `/data/data/com.termux/files/usr/bin/login` which
                // requires the Termux app to be installed — not an
                // option for us.
                shellPath = "/system/bin/sh",
                cwd = "/",
                args = arrayOf("/system/bin/sh"),
                env = arrayOf(
                    "TERM=xterm-256color",
                    "HOME=/",
                    "PATH=/system/bin:/system/xbin",
                ),
            )
        }
    }

    // data class with arrays: opt into structural equality so the
    // JUnit test below can assert on `copy()` round-trips without
    // relying on identity. Cheap enough at the call rate (once per
    // mount).
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TermuxSessionConfig) return false
        return shellPath == other.shellPath &&
            cwd == other.cwd &&
            args.contentEquals(other.args) &&
            env.contentEquals(other.env)
    }

    override fun hashCode(): Int {
        var r = shellPath.hashCode()
        r = 31 * r + cwd.hashCode()
        r = 31 * r + args.contentHashCode()
        r = 31 * r + env.contentHashCode()
        return r
    }
}

/**
 * Stage 1 no-op [TerminalViewClient]. Every method either returns the
 * Termux default or drops the event. Stage 2 will replace this with a
 * real implementation that forwards key events through
 * `SessionStore.sendInput` and routes IME / accessory-bar state
 * through Compose. Kept as an `object` so the no-op shape is shared
 * across all sessions (the client is stateless at Stage 1).
 */
private object NoopTerminalViewClient : TerminalViewClient {
    override fun onScale(scale: Float): Float = 1f
    override fun onSingleTapUp(e: MotionEvent) {}
    override fun shouldBackButtonBeMappedToEscape(): Boolean = false
    override fun shouldEnforceCharBasedInput(): Boolean = false
    override fun shouldUseCtrlSpaceWorkaround(): Boolean = false
    override fun isTerminalViewSelected(): Boolean = true
    override fun copyModeChanged(copyMode: Boolean) {}
    override fun onKeyDown(
        keyCode: Int,
        e: KeyEvent?,
        session: TerminalSession?,
    ): Boolean = false
    override fun onKeyUp(keyCode: Int, e: KeyEvent?): Boolean = false
    override fun onLongPress(event: MotionEvent?): Boolean = false
    override fun readControlKey(): Boolean = false
    override fun readAltKey(): Boolean = false
    override fun readShiftKey(): Boolean = false
    override fun readFnKey(): Boolean = false
    override fun onCodePoint(
        codePoint: Int,
        ctrlDown: Boolean,
        session: TerminalSession?,
    ): Boolean = false
    override fun onEmulatorSet() {}
    override fun logError(tag: String?, message: String?) {
        Log.e(tag ?: TAG, message ?: "")
    }
    override fun logWarn(tag: String?, message: String?) {
        Log.w(tag ?: TAG, message ?: "")
    }
    override fun logInfo(tag: String?, message: String?) {
        Log.i(tag ?: TAG, message ?: "")
    }
    override fun logDebug(tag: String?, message: String?) {
        Log.d(tag ?: TAG, message ?: "")
    }
    override fun logVerbose(tag: String?, message: String?) {
        Log.v(tag ?: TAG, message ?: "")
    }
    override fun logStackTraceWithMessage(tag: String?, message: String?, e: Exception?) {
        Log.e(tag ?: TAG, message ?: "", e)
    }
    override fun logStackTrace(tag: String?, e: Exception?) {
        Log.e(tag ?: TAG, "", e)
    }
}

/**
 * Stage 1 no-op [TerminalSessionClient]. Same shape as
 * [NoopTerminalViewClient] — every callback drops the event.
 */
private object NoopTerminalSessionClient : TerminalSessionClient {
    override fun onTextChanged(changedSession: TerminalSession?) {}
    override fun onTitleChanged(changedSession: TerminalSession?) {}
    override fun onSessionFinished(finishedSession: TerminalSession?) {}
    override fun onCopyTextToClipboard(session: TerminalSession?, text: String?) {}
    override fun onPasteTextFromClipboard(session: TerminalSession?) {}
    override fun onBell(session: TerminalSession?) {}
    override fun onColorsChanged(session: TerminalSession?) {}
    override fun onTerminalCursorStateChange(state: Boolean) {}
    override fun getTerminalCursorStyle(): Int? = null
    override fun logError(tag: String?, message: String?) {
        Log.e(tag ?: TAG, message ?: "")
    }
    override fun logWarn(tag: String?, message: String?) {
        Log.w(tag ?: TAG, message ?: "")
    }
    override fun logInfo(tag: String?, message: String?) {
        Log.i(tag ?: TAG, message ?: "")
    }
    override fun logDebug(tag: String?, message: String?) {
        Log.d(tag ?: TAG, message ?: "")
    }
    override fun logVerbose(tag: String?, message: String?) {
        Log.v(tag ?: TAG, message ?: "")
    }
    override fun logStackTraceWithMessage(tag: String?, message: String?, e: Exception?) {
        Log.e(tag ?: TAG, message ?: "", e)
    }
    override fun logStackTrace(tag: String?, e: Exception?) {
        Log.e(tag ?: TAG, "", e)
    }
}

/**
 * Stage 0 fallback. Kept exported so the try/catch above can still
 * mount it when the Termux dep fails to resolve. Same visual shape
 * the placeholder used before Stage 1.
 */
internal class TermuxPlaceholderView(context: Context) : FrameLayout(context) {
    init {
        setBackgroundColor(AndroidColor.BLACK)
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )

        val label = TextView(context).apply {
            text = "Termux unavailable — falling back to placeholder " +
                "(see PLAN-TERMINAL-REWRITE Android section)"
            setTextColor(AndroidColor.WHITE)
            textSize = 13f
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(48, 24, 48, 24)
        }
        val lp = LayoutParams(
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
        ).apply { gravity = Gravity.CENTER }
        addView(label, lp)
    }

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
