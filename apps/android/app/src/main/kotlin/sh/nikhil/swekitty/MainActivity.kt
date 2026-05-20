package sh.nikhil.swekitty

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import sh.nikhil.swekitty.ui.AppRoot

class MainActivity : ComponentActivity() {
    private val store: SessionStore by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Telemetry.configure(applicationContext)
        store.hydrate(applicationContext)
        handlePairingIntent(intent)
        setContent {
            MaterialTheme {
                // GlassAppBackground inside AppRoot supplies the canvas; no
                // opaque Surface wrap so the glass layering reads correctly.
                AppRoot(store)
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePairingIntent(intent)
    }

    private fun handlePairingIntent(intent: android.content.Intent?) {
        val data = intent?.data ?: return
        if (data.scheme?.lowercase() != "swekitty") return
        store.applyDeepLink(data.toString())
    }
}
