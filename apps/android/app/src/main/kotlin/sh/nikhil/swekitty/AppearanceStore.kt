package sh.nikhil.swekitty

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * User-tunable appearance settings: chat body font, theme override,
 * and turn-collapse preference. Persisted to plain SharedPreferences
 * (these aren't secrets — no encryption needed).
 *
 * Mirrors `apps/ios/Sources/Models/AppearanceStore.swift`. Plan called
 * for DataStore but SharedPreferences keeps the dependency surface
 * smaller and is consistent with [SessionStore]'s prefs pattern.
 */
class AppearanceStore : ViewModel() {

    enum class FontFamily(val label: String) {
        Monospaced("Monospaced"),
        System("System"),
    }

    enum class ThemeMode(val label: String) {
        System("System"),
        Light("Light"),
        Dark("Dark"),
    }

    private val _fontFamily = MutableStateFlow(FontFamily.Monospaced)
    val fontFamily: StateFlow<FontFamily> = _fontFamily.asStateFlow()

    private val _themeMode = MutableStateFlow(ThemeMode.System)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _collapseTurns = MutableStateFlow(false)
    val collapseTurns: StateFlow<Boolean> = _collapseTurns.asStateFlow()

    /**
     * Stage 0 feature flag for the Termux `terminal-view` native
     * terminal path. Mirrors iOS `experimentalNativeTerminal`. Off by
     * default — the xterm.js path ([WebTerminal]) remains the
     * production renderer until Stage 2 of the rewrite ships. See
     * `docs/PLAN-TERMINAL-REWRITE.md` (Android section).
     */
    private val _experimentalNativeTerminal = MutableStateFlow(false)
    val experimentalNativeTerminal: StateFlow<Boolean> = _experimentalNativeTerminal.asStateFlow()

    private var prefs: SharedPreferences? = null

    fun hydrate(ctx: Context) {
        val p = ctx.getSharedPreferences("swekitty.appearance", Context.MODE_PRIVATE)
        prefs = p
        _fontFamily.value = p.getString(KEY_FONT, null)
            ?.let { runCatching { FontFamily.valueOf(it) }.getOrNull() }
            ?: FontFamily.Monospaced
        _themeMode.value = p.getString(KEY_THEME, null)
            ?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() }
            ?: ThemeMode.System
        _collapseTurns.value = p.getBoolean(KEY_COLLAPSE, false)
        _experimentalNativeTerminal.value = p.getBoolean(KEY_EXPERIMENTAL_NATIVE_TERMINAL, false)
    }

    fun setFontFamily(value: FontFamily) {
        _fontFamily.value = value
        prefs?.edit()?.putString(KEY_FONT, value.name)?.apply()
    }

    fun setThemeMode(value: ThemeMode) {
        _themeMode.value = value
        prefs?.edit()?.putString(KEY_THEME, value.name)?.apply()
    }

    fun setCollapseTurns(value: Boolean) {
        _collapseTurns.value = value
        prefs?.edit()?.putBoolean(KEY_COLLAPSE, value)?.apply()
    }

    fun setExperimentalNativeTerminal(value: Boolean) {
        _experimentalNativeTerminal.value = value
        prefs?.edit()?.putBoolean(KEY_EXPERIMENTAL_NATIVE_TERMINAL, value)?.apply()
    }

    private companion object {
        const val KEY_FONT = "font"
        const val KEY_THEME = "theme"
        const val KEY_COLLAPSE = "collapseTurns"
        const val KEY_EXPERIMENTAL_NATIVE_TERMINAL = "experimentalNativeTerminal"
    }
}

/**
 * CompositionLocal so any composable below `AppRoot` can read
 * appearance without threading the store through every parameter list.
 */
val LocalAppearanceStore = staticCompositionLocalOf<AppearanceStore> {
    error("AppearanceStore not provided")
}
