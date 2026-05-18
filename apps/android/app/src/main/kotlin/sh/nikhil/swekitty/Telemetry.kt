package sh.nikhil.swekitty

import android.content.Context
import io.sentry.Sentry
import io.sentry.SentryLevel
import io.sentry.android.core.SentryAndroid

object Telemetry {
    fun configure(context: Context) {
        val dsn = BuildConfig.SENTRY_DSN.trim()
        if (dsn.isEmpty()) return
        SentryAndroid.init(context) { options ->
            options.dsn = dsn
            options.environment = "android"
            options.isEnableAutoSessionTracking = true
        }
    }

    fun capture(error: Throwable, message: String, tags: Map<String, String> = emptyMap(), extras: Map<String, String> = emptyMap()) {
        val dsn = BuildConfig.SENTRY_DSN.trim()
        if (dsn.isEmpty()) return
        Sentry.withScope { scope ->
            scope.level = SentryLevel.ERROR
            tags.forEach { (key, value) -> scope.setTag(key, value) }
            extras.forEach { (key, value) -> scope.setExtra(key, value) }
            Sentry.captureMessage(message, SentryLevel.ERROR)
            Sentry.captureException(error)
        }
    }
}
