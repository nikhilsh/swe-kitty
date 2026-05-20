package sh.nikhil.swekitty.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Brightness6
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import sh.nikhil.swekitty.AppearanceStore

/**
 * Modal sheet for the Theme + Font controls, opened from
 * Settings → Appearance → Theme. Mirrors `AppearanceSheet.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppearanceSheet(appearance: AppearanceStore, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val themeMode by appearance.themeMode.collectAsState()
    val fontFamily by appearance.fontFamily.collectAsState()

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Text(
                "Appearance",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )

            SettingsSection("Theme") {
                AppearanceStore.ThemeMode.values().forEachIndexed { idx, choice ->
                    PickerRow(
                        icon = iconFor(choice),
                        title = choice.label,
                        isSelected = themeMode == choice,
                        onClick = { appearance.setThemeMode(choice) },
                    )
                    if (idx < AppearanceStore.ThemeMode.values().lastIndex) HorizontalDivider()
                }
            }

            SettingsSection("Chat Body Font") {
                AppearanceStore.FontFamily.values().forEachIndexed { idx, choice ->
                    PickerRow(
                        icon = if (choice == AppearanceStore.FontFamily.Monospaced) Icons.Filled.Code else Icons.Filled.TextFields,
                        title = choice.label,
                        isSelected = fontFamily == choice,
                        onClick = { appearance.setFontFamily(choice) },
                    )
                    if (idx < AppearanceStore.FontFamily.values().lastIndex) HorizontalDivider()
                }
            }

            Spacer(Modifier.height(12.dp))
        }
    }
}

private fun iconFor(mode: AppearanceStore.ThemeMode): ImageVector = when (mode) {
    AppearanceStore.ThemeMode.System -> Icons.Filled.Brightness6
    AppearanceStore.ThemeMode.Light -> Icons.Filled.LightMode
    AppearanceStore.ThemeMode.Dark -> Icons.Filled.DarkMode
}
