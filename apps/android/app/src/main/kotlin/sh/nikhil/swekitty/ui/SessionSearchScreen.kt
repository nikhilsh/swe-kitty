package sh.nikhil.swekitty.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ProjectSession

/**
 * Cross-session search modal — opened from the bottom-bar magnifying
 * glass. v1 client-side index over `conversationLog` + session metadata.
 * Mirrors `apps/ios/Sources/Views/SessionSearchView.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionSearchScreen(store: SessionStore, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val sessions by store.sessions.collectAsState()
    val conversationLog by store.conversationLog.collectAsState()
    val displayNames by store.displayNames.collectAsState()
    var query by remember { mutableStateOf("") }

    val results by remember(query, sessions, conversationLog) {
        derivedStateOf {
            val needle = query.trim().lowercase()
            if (needle.isEmpty()) emptyList()
            else sessions.mapNotNull { s ->
                val titleHit = s.name.lowercase().contains(needle)
                val agentHit = s.assistant.lowercase().contains(needle)
                val branchHit = (s.branch ?: "").lowercase().contains(needle)
                val snippet = matchSnippet(s, needle, conversationLog[s.id].orEmpty())
                if (snippet != null || titleHit || agentHit || branchHit) {
                    SearchHit(
                        sessionId = s.id,
                        title = displayNames[s.id] ?: s.name,
                        subtitle = snippet ?: "${s.assistant} · ${s.branch ?: "no branch"}",
                    )
                } else null
            }
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("Search", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)

            Surface(
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Search, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.width(8.dp))
                    BasicTextField(
                        value = query,
                        onValueChange = { query = it },
                        textStyle = MaterialTheme.typography.bodyMedium.copy(
                            color = MaterialTheme.colorScheme.onSurface,
                        ),
                        decorationBox = { inner ->
                            if (query.isEmpty()) {
                                Text(
                                    "Search sessions, transcripts, paths…",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            inner()
                        },
                        modifier = Modifier.fillMaxWidth().weight(1f, fill = true),
                    )
                    if (query.isNotEmpty()) {
                        Icon(
                            Icons.Default.Cancel,
                            contentDescription = "Clear",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp).clickable { query = "" },
                        )
                    }
                }
            }

            if (results.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        if (query.isEmpty()) "Search every session" else "No matches",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        if (query.isEmpty())
                            "Type to scan conversation history across saved servers."
                        else
                            "Try a different query.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    results.forEach { result ->
                        Surface(
                            shape = RoundedCornerShape(SweKittyTheme.cardCornerRadiusDp.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                            modifier = Modifier.fillMaxWidth().clickable {
                                store.select(result.sessionId)
                                onDismiss()
                            },
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                HealthDot("unknown")
                                Spacer(Modifier.width(10.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        result.title,
                                        style = MaterialTheme.typography.titleSmall,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    Text(
                                        result.subtitle,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                Icon(
                                    Icons.Default.ChevronRight,
                                    null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun matchSnippet(
    session: ProjectSession,
    needle: String,
    events: List<uniffi.swe_kitty_core.ConversationItem>,
): String? {
    for (ev in events.asReversed()) {
        val lower = ev.content.lowercase()
        val idx = lower.indexOf(needle)
        if (idx >= 0) {
            val start = (idx - 20).coerceAtLeast(0)
            val end = (idx + needle.length + 40).coerceAtMost(ev.content.length)
            return ev.content.substring(start, end).trim()
        }
    }
    return null
}

private data class SearchHit(val sessionId: String, val title: String, val subtitle: String)
