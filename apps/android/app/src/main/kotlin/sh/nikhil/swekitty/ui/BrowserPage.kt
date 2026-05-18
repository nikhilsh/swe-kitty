package sh.nikhil.swekitty.ui

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ProjectSession

enum class BrowserMode { Preview, Memory }

@Composable
fun BrowserPage(store: SessionStore, session: ProjectSession, mode: BrowserMode = BrowserMode.Preview) {
    val previews by store.previews.collectAsState()
    val endpoint by store.endpoint.collectAsState()
    val base = endpoint.httpBaseUrl

    val resolved: String? = when (mode) {
        BrowserMode.Preview -> previews[session.id]?.url?.let { resolve(base, it) }
        BrowserMode.Memory  -> resolve(base, "/memory/sessions/${session.id}.html")
    }

    if (resolved == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                when (mode) {
                    BrowserMode.Preview -> "No preview yet"
                    BrowserMode.Memory  -> "No memory yet"
                },
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        return
    }

    AndroidView(
        factory = { ctx ->
            WebView(ctx).apply {
                webViewClient = WebViewClient()
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                loadUrl(resolved)
            }
        },
        update = { view ->
            if (view.url != resolved) view.loadUrl(resolved)
        },
        modifier = Modifier.fillMaxSize(),
    )
}

private fun resolve(base: String?, pathOrUrl: String): String? {
    val lower = pathOrUrl.lowercase()
    if (lower.startsWith("http://") || lower.startsWith("https://")) return pathOrUrl
    if (base.isNullOrBlank()) return null
    val sep = if (pathOrUrl.startsWith("/")) "" else "/"
    return "$base$sep$pathOrUrl"
}
