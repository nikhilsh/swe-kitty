package sh.nikhil.swekitty.ui

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/**
 * Brief launch splash — Compose mirror of
 * `apps/ios/Sources/Views/AnimatedSplashView.swift`. Springs in,
 * holds, then fades out over ~1.2s total. Drawn over the regular
 * `GlassAppBackground` so the underlying canvas is the same.
 */
@Composable
fun AnimatedSplash(onFinish: () -> Unit) {
    var entered by remember { mutableStateOf(false) }
    var visible by remember { mutableStateOf(true) }

    val scale by animateFloatAsState(
        targetValue = if (entered) 1f else 0.85f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMediumLow,
        ),
        label = "splash-scale",
    )
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 350),
        label = "splash-alpha",
    )

    LaunchedEffect(Unit) {
        entered = true
        delay(850)
        visible = false
        delay(360)
        onFinish()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .alpha(alpha),
    ) {
        GlassAppBackground()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .scale(scale),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                Icons.Default.Pets,
                contentDescription = null,
                tint = SweKittyTheme.accentStrong(),
                modifier = Modifier.size(84.dp),
            )
            Text(
                "SweKitty",
                color = SweKittyTheme.textPrimary(),
                fontWeight = FontWeight.Bold,
                fontSize = 40.sp,
            )
        }
    }
}
