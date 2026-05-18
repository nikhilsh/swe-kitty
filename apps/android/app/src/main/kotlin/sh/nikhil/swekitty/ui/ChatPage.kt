package sh.nikhil.swekitty.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.SmartToy
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ChatEvent
import uniffi.swe_kitty_core.ProjectSession

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatPage(store: SessionStore, session: ProjectSession) {
    val log by store.chatLog.collectAsState()
    val events = log[session.id] ?: emptyList()
    var draft by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(events.size) {
        if (events.isNotEmpty()) listState.animateScrollToItem(events.size - 1)
    }

    Column(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(events) { ev -> ChatRow(ev) }
        }
        HorizontalDivider()
        Row(
            modifier = Modifier.fillMaxWidth().padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text("Message agent…") },
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = {
                val msg = draft.trim()
                if (msg.isNotEmpty()) {
                    store.sendChat(session.id, msg)
                    draft = ""
                }
            }) { Icon(Icons.Default.Send, contentDescription = "Send") }
        }
    }
}

@Composable
private fun ChatRow(ev: ChatEvent) {
    val (bubble, icon) = when (ev.role) {
        "user"      -> Color(0x33_2D7BFF) to Icons.Outlined.AccountCircle
        "assistant" -> Color(0x22_64748B) to Icons.Outlined.SmartToy
        "tool"      -> Color(0x33_FB923C) to Icons.Outlined.Build
        else        -> Color(0x14_64748B) to Icons.Outlined.SmartToy
    }
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(4.dp))
            Text(
                ev.role.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (ev.ts.isNotEmpty()) {
                Spacer(Modifier.width(6.dp))
                Text(ev.ts, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
            }
        }
        Spacer(Modifier.height(2.dp))
        SelectionContainer {
            Text(
                ev.content,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(bubble)
                    .padding(horizontal = 10.dp, vertical = 8.dp),
            )
        }
        if (ev.files.isNotEmpty()) {
            Spacer(Modifier.height(2.dp))
            Column(modifier = Modifier.padding(start = 4.dp)) {
                ev.files.forEach { f ->
                    Text(
                        text = if (f.rev.isNotEmpty()) "📄 ${f.path} @${f.rev.take(7)}" else "📄 ${f.path}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
