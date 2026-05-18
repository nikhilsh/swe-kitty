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
        setContent {
            MaterialTheme {
                // GlassAppBackground inside AppRoot supplies the canvas; no
                // opaque Surface wrap so the glass layering reads correctly.
                AppRoot(store)
            }
        }
    }
}
