package sh.nikhil.swekitty.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle

/**
 * Minimal ANSI/VT100 renderer for the terminal tab.
 *
 * Real PTY emulation (cursor positioning, alternate screen, scroll
 * regions) is a separate problem — the only thing we need to ship
 * v0.x is text that doesn't look garbled. So this:
 *
 *  - Parses CSI `ESC[…m` SGR sequences (colors, bold/italic/underline,
 *    24-bit RGB, xterm-256, dim, reset).
 *  - Honors `\n` as a line break and `\r` as a "back to column 0 of
 *    the current line — subsequent chars overwrite" (matches what
 *    spinners and progress bars expect).
 *  - Strips other CSI sequences (cursor moves, screen clears).
 *  - Strips OSC `ESC]…BEL` / `ESC]…ESC\` (title sets, hyperlinks).
 *  - Drops other C0 control chars.
 *
 * Re-parses the whole buffer on each call. v1 cost; an incremental
 * stateful version can come later if scrollback gets long enough to
 * matter.
 */
fun renderAnsi(bytes: ByteArray): AnnotatedString {
    if (bytes.isEmpty()) return AnnotatedString("")
    val text = String(bytes, Charsets.UTF_8)
    val lines = mutableListOf<MutableList<Cell>>()
    var line = mutableListOf<Cell>()
    lines.add(line)
    var col = 0
    var style = SpanStyle()
    var i = 0
    while (i < text.length) {
        val c = text[i]
        when {
            c == ESC && i + 1 < text.length && text[i + 1] == '[' -> {
                // CSI: read params until a final byte in 0x40..0x7E.
                var j = i + 2
                while (j < text.length && text[j].code in 0x30..0x3F) j++ // params
                while (j < text.length && text[j].code in 0x20..0x2F) j++ // intermediates
                if (j < text.length) {
                    val finalByte = text[j]
                    val params = text.substring(i + 2, j)
                    if (finalByte == 'm') {
                        style = applySgr(style, params)
                    }
                    i = j + 1
                } else {
                    i = text.length
                }
            }
            c == ESC && i + 1 < text.length && text[i + 1] == ']' -> {
                // OSC: ESC ] … BEL  OR  ESC ] … ESC \
                var j = i + 2
                while (j < text.length) {
                    if (text[j] == BEL) { j++; break }
                    if (text[j] == ESC && j + 1 < text.length && text[j + 1] == '\\') {
                        j += 2; break
                    }
                    j++
                }
                i = j
            }
            c == '\n' -> {
                line = mutableListOf()
                lines.add(line)
                col = 0
                i++
            }
            c == '\r' -> {
                col = 0
                i++
            }
            c == '\b' -> {
                if (col > 0) col--
                i++
            }
            c.code < 0x20 || c.code == 0x7F -> {
                // C0 control / DEL: drop
                i++
            }
            else -> {
                if (col < line.size) {
                    line[col] = Cell(c, style)
                } else {
                    while (line.size < col) line.add(Cell(' ', SpanStyle()))
                    line.add(Cell(c, style))
                }
                col++
                i++
            }
        }
    }

    // Flatten into a single AnnotatedString with run-length style spans.
    return buildAnnotatedString {
        for ((idx, ln) in lines.withIndex()) {
            var runStart = 0
            while (runStart < ln.size) {
                val runStyle = ln[runStart].style
                var runEnd = runStart + 1
                while (runEnd < ln.size && ln[runEnd].style == runStyle) runEnd++
                withStyle(runStyle) {
                    for (k in runStart until runEnd) append(ln[k].ch)
                }
                runStart = runEnd
            }
            if (idx < lines.size - 1) append('\n')
        }
    }
}

private data class Cell(val ch: Char, val style: SpanStyle)

private const val ESC = '\u001B'
private const val BEL = '\u0007'

private fun applySgr(initial: SpanStyle, params: String): SpanStyle {
    val parts = if (params.isEmpty()) listOf("0") else params.split(';')
    var style = initial
    var i = 0
    while (i < parts.size) {
        val p = parts[i].toIntOrNull() ?: 0
        when (p) {
            0 -> style = SpanStyle()
            1 -> style = style.copy(fontWeight = FontWeight.Bold)
            2 -> style = style.copy(color = style.color.copy(alpha = 0.6f).takeIfSpecified()
                ?: Color(0xFF8E8E93))
            3 -> style = style.copy(fontStyle = FontStyle.Italic)
            4 -> style = style.copy(textDecoration = TextDecoration.Underline)
            9 -> style = style.copy(textDecoration = TextDecoration.LineThrough)
            22 -> style = style.copy(fontWeight = FontWeight.Normal)
            23 -> style = style.copy(fontStyle = FontStyle.Normal)
            24, 29 -> style = style.copy(textDecoration = TextDecoration.None)
            in 30..37 -> style = style.copy(color = ANSI_FG[p - 30])
            in 90..97 -> style = style.copy(color = ANSI_FG_BRIGHT[p - 90])
            in 40..47 -> style = style.copy(background = ANSI_BG[p - 40])
            in 100..107 -> style = style.copy(background = ANSI_BG_BRIGHT[p - 100])
            39 -> style = style.copy(color = Color.Unspecified)
            49 -> style = style.copy(background = Color.Unspecified)
            38 -> {
                val mode = parts.getOrNull(i + 1)?.toIntOrNull() ?: 0
                when (mode) {
                    5 -> {
                        val n = parts.getOrNull(i + 2)?.toIntOrNull() ?: 0
                        style = style.copy(color = xterm256(n)); i += 2
                    }
                    2 -> {
                        val r = parts.getOrNull(i + 2)?.toIntOrNull() ?: 0
                        val g = parts.getOrNull(i + 3)?.toIntOrNull() ?: 0
                        val b = parts.getOrNull(i + 4)?.toIntOrNull() ?: 0
                        style = style.copy(color = Color(r, g, b)); i += 4
                    }
                }
            }
            48 -> {
                val mode = parts.getOrNull(i + 1)?.toIntOrNull() ?: 0
                when (mode) {
                    5 -> {
                        val n = parts.getOrNull(i + 2)?.toIntOrNull() ?: 0
                        style = style.copy(background = xterm256(n)); i += 2
                    }
                    2 -> {
                        val r = parts.getOrNull(i + 2)?.toIntOrNull() ?: 0
                        val g = parts.getOrNull(i + 3)?.toIntOrNull() ?: 0
                        val b = parts.getOrNull(i + 4)?.toIntOrNull() ?: 0
                        style = style.copy(background = Color(r, g, b)); i += 4
                    }
                }
            }
        }
        i++
    }
    return style
}

private fun Color.takeIfSpecified(): Color? =
    if (this == Color.Unspecified) null else this

// xterm "8-bit" palette: 16 ANSI, then a 6×6×6 RGB cube, then 24 grays.
private fun xterm256(n: Int): Color = when {
    n < 0 -> Color.Unspecified
    n < 16 -> ANSI_256_BASE[n]
    n < 232 -> {
        val k = n - 16
        val r = (k / 36) % 6
        val g = (k / 6) % 6
        val b = k % 6
        Color(STEP[r], STEP[g], STEP[b])
    }
    n < 256 -> {
        val v = 8 + (n - 232) * 10
        Color(v, v, v)
    }
    else -> Color.Unspecified
}

private val STEP = intArrayOf(0, 95, 135, 175, 215, 255)

// Reasonable defaults for a dark terminal (close to iTerm "Dark Background").
private val ANSI_FG = arrayOf(
    Color(0xFF6E6E6E), // black
    Color(0xFFFF5C5C), // red
    Color(0xFF7BE38B), // green
    Color(0xFFFFD866), // yellow
    Color(0xFF7CB6FF), // blue
    Color(0xFFE48FE5), // magenta
    Color(0xFF6CD8E6), // cyan
    Color(0xFFD8D8D8), // white
)
private val ANSI_FG_BRIGHT = arrayOf(
    Color(0xFF8E8E8E),
    Color(0xFFFF7A7A),
    Color(0xFFA0F0AE),
    Color(0xFFFFE08C),
    Color(0xFFA0C8FF),
    Color(0xFFF0A8F0),
    Color(0xFF8AE8F0),
    Color(0xFFF0F0F0),
)
private val ANSI_BG = ANSI_FG
private val ANSI_BG_BRIGHT = ANSI_FG_BRIGHT
private val ANSI_256_BASE = ANSI_FG + ANSI_FG_BRIGHT
