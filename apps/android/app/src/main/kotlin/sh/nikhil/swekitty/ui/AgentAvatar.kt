package sh.nikhil.swekitty.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Code
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Compose mirror of `apps/ios/Sources/Views/AgentAvatar.swift`.
 *
 * Small circular avatar for an agent (claude, codex, hermes, pi,
 * opencode). Used in any place that lists or picks agents — the
 * `AgentPickerSheet` rows, the thread switcher row list, and the
 * `SessionInfoScreen` hero. Not used inside the chat composer or the
 * header pill — those are already tinted via
 * [SweKittyTheme.accent].
 *
 * Renders a single-letter monogram on a filled disc using
 * [SweKittyTheme.accentStrong]. Falling back to a letter (rather
 * than a logo) means we don't ship third-party brand marks in the
 * APK and the avatar works for any agent the harness exposes.
 */
@Composable
fun AgentAvatar(
    assistant: String,
    modifier: Modifier = Modifier,
    size: Dp = 24.dp,
) {
    val fill = SweKittyTheme.accentStrong(forAgent = assistant)
    val onAccent = SweKittyTheme.textOnAccent()
    val glyph = agentGlyph(assistant)
    val monogram = monogramFor(assistant)
    val label = assistant.replaceFirstChar { it.uppercaseChar() }

    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(fill)
            .border(0.5.dp, onAccent.copy(alpha = 0.15f), CircleShape)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        if (glyph != null) {
            // Claude / Codex get a distinctive brand glyph; other agents
            // keep the monogram.
            Icon(
                imageVector = glyph,
                contentDescription = null,
                tint = onAccent,
                modifier = Modifier.size(size * 0.5f),
            )
        } else {
            Text(
                text = monogram,
                color = onAccent,
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = (size.value * 0.5f).sp,
                ),
            )
        }
    }
}

/**
 * Per-agent brand glyph. Claude → a sparkle, Codex → the code-brackets
 * mark. Returns null for agents we don't have a glyph for (they fall
 * back to [monogramFor]). Neutral Material symbols rather than shipping
 * Anthropic / OpenAI logo artwork in the APK. The string key is exposed
 * via [agentGlyphKey] for plain-JVM unit tests.
 */
private fun agentGlyph(assistant: String): ImageVector? = when (agentGlyphKey(assistant)) {
    "sparkle" -> Icons.Filled.AutoAwesome
    "code"    -> Icons.Filled.Code
    else      -> null
}

internal fun agentGlyphKey(assistant: String): String? = when (assistant.lowercase()) {
    "claude" -> "sparkle"
    "codex"  -> "code"
    else     -> null
}

/**
 * Per-agent monogram. Codex breaks the "first letter" pattern — "C"
 * already belongs to Claude, so Codex gets "X" (Codex eXecution, and
 * visually distinct from C). Everything else is the first letter.
 */
internal fun monogramFor(assistant: String): String = when (assistant.lowercase()) {
    "claude"   -> "C"
    "codex"    -> "X"
    "hermes"   -> "H"
    "pi"       -> "π"
    "opencode" -> "O"
    else       -> assistant.take(1).uppercase()
}

/** Visible-for-tests overload that bypasses Compose for unit tests. */
internal fun agentAvatarMonogram(assistant: String): String = monogramFor(assistant)
