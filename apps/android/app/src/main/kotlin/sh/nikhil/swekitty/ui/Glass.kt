package sh.nikhil.swekitty.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * Compose mirror of `apps/ios/Sources/Theme/Glass.swift`. The iOS code
 * gates the real Liquid Glass `glassEffect` modifier behind `#available
 * iOS 26`; we always render the fallback (layered tint + gradient
 * highlight + soft stroke + drop shadow). Visual direction matches.
 *
 * Compose can't easily replicate `.ultraThinMaterial` (a system blur
 * applied to whatever is behind), so we approximate with a translucent
 * tinted surface over the app background. The accent wash in
 * [GlassAppBackground] gives the surfaces something to refract against.
 */

@Composable
fun Modifier.glassRect(
    cornerRadiusDp: Float = SweKittyTheme.cardCornerRadiusDp,
    tint: Color? = null,
): Modifier = glassSurface(
    shape = RoundedCornerShape(cornerRadiusDp.dp),
    tint = tint,
)

@Composable
fun Modifier.glassRoundedRect(
    cornerRadiusDp: Float = SweKittyTheme.cardCornerRadiusDp,
): Modifier = glassSurface(
    shape = RoundedCornerShape(cornerRadiusDp.dp),
    tint = null,
)

@Composable
fun Modifier.glassCapsule(
    interactive: Boolean = false,
    tint: Color? = null,
): Modifier = glassSurface(
    shape = RoundedCornerShape(percent = 50),
    tint = tint,
    highlightOpacity = if (interactive) 0.34f else 0.22f,
    shadowOpacity = if (interactive) 0.22f else 0.14f,
)

@Composable
fun Modifier.glassCircle(tint: Color? = null): Modifier = glassSurface(
    shape = CircleShape,
    tint = tint,
    highlightOpacity = 0.28f,
)

@Composable
private fun Modifier.glassSurface(
    shape: Shape,
    tint: Color?,
    highlightOpacity: Float = 0.24f,
    shadowOpacity: Float = 0.16f,
): Modifier {
    val accent = SweKittyTheme.accentStrong()
    val border = SweKittyTheme.border()
    val surfaceLight = SweKittyTheme.surfaceLight()
    val textPrimary = SweKittyTheme.textPrimary()
    val baseTint = tint ?: SweKittyPalette.surface.color()

    val stroke = (tint ?: border).copy(alpha = 0.42f)
    val glow = (tint ?: accent).copy(alpha = highlightOpacity)

    return this
        .shadow(elevation = 18.dp, shape = shape, ambientColor = textPrimary, spotColor = textPrimary)
        .clip(shape)
        // Layer 1: translucent fill so the underlying background bleeds through.
        .background(color = baseTint.copy(alpha = 0.55f), shape = shape)
        // Layer 2: top-leading highlight gradient.
        .background(
            brush = Brush.linearGradient(
                colors = listOf(
                    glow,
                    surfaceLight.copy(alpha = 0.08f),
                    Color.Transparent,
                ),
            ),
            shape = shape,
        )
        .border(width = 1.dp, color = stroke, shape = shape)
}
