package sh.nikhil.swekitty.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.AccountTree
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import sh.nikhil.swekitty.SessionStore
import uniffi.swe_kitty_core.ProjectSession

enum class ProjectTab(val label: String) { Terminal("Terminal"), Chat("Chat"), Browser("Browser") }

/**
 * Litter-style chat header card (Stage 2):
 *  Row 1: agent dropdown · refresh · info
 *  Row 2: project path (mono, muted) + status subtitle
 *  Row 3: Terminal / Chat / Browser segmented picker
 *
 * Mirrors `apps/ios/Sources/Views/ProjectView.swift`.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun ProjectScreen(
    store: SessionStore,
    session: ProjectSession,
    onOpenDrawer: () -> Unit,
) {
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { ProjectTab.entries.size })
    val statuses by store.statusBySession.collectAsState()
    val status = statuses[session.id]
    var menuExpanded by remember { mutableStateOf(false) }
    var browserMode by remember { mutableStateOf(BrowserMode.Preview) }
    var showInfo by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val agentAccent = SweKittyTheme.accent(forAgent = session.assistant)

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 10.dp).padding(top = 8.dp)) {
        Surface(
            shape = RoundedCornerShape(SweKittyTheme.cardCornerRadiusDp.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    // Drawer toggle — left edge of the header so the
                    // sessions list is still one tap away.
                    HeaderCircleButton(icon = Icons.Default.Menu, contentDescription = "Sessions", onClick = onOpenDrawer)
                    // Agent dropdown — primary affordance.
                    Box {
                        Surface(
                            shape = RoundedCornerShape(50),
                            color = agentAccent.copy(alpha = 0.32f),
                            modifier = Modifier.clickable { menuExpanded = true },
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                HealthDot(status?.health ?: "unknown")
                                Text(
                                    session.assistant,
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Icon(Icons.Outlined.AccountTree, null, modifier = Modifier.size(14.dp))
                            }
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("Switch to Claude") },
                                enabled = session.assistant != "claude",
                                onClick = { menuExpanded = false; store.switchAgent(session.id, "claude") },
                            )
                            DropdownMenuItem(
                                text = { Text("Switch to Codex") },
                                enabled = session.assistant != "codex",
                                onClick = { menuExpanded = false; store.switchAgent(session.id, "codex") },
                            )
                            HorizontalDivider()
                            DropdownMenuItem(
                                text = { Text("End session") },
                                onClick = { menuExpanded = false; store.exit(session.id) },
                            )
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    MemoryButton(
                        currentMode = browserMode,
                        onToggle = { browserMode = it },
                        onJumpToBrowser = { scope.launch { pagerState.animateScrollToPage(ProjectTab.Browser.ordinal) } },
                    )
                    HeaderCircleButton(icon = Icons.Default.Refresh, contentDescription = "Reconnect", onClick = { store.reconnect() })
                    HeaderCircleButton(icon = Icons.Outlined.Info, contentDescription = "Session info", onClick = { showInfo = true })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Outlined.Folder,
                        null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        session.name,
                        style = MaterialTheme.typography.labelMedium,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    val subtitleParts = mutableListOf<String>()
                    session.branch?.takeIf { it.isNotBlank() }?.let { subtitleParts.add(it) }
                    status?.phase?.takeIf { it.isNotBlank() }?.let { subtitleParts.add(it) }
                    if (subtitleParts.isNotEmpty()) {
                        Text(
                            subtitleParts.joinToString(" · "),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TabRow(
                    selectedTabIndex = pagerState.currentPage,
                    containerColor = androidx.compose.ui.graphics.Color.Transparent,
                ) {
                    ProjectTab.entries.forEachIndexed { i, t ->
                        Tab(
                            selected = pagerState.currentPage == i,
                            onClick = { scope.launch { pagerState.animateScrollToPage(i) } },
                            text = { Text(t.label, fontWeight = FontWeight.SemiBold) },
                            icon = {
                                Icon(
                                    when (t) {
                                        ProjectTab.Terminal -> Icons.Outlined.Terminal
                                        ProjectTab.Chat     -> Icons.Outlined.Chat
                                        ProjectTab.Browser  -> Icons.Outlined.Public
                                    },
                                    contentDescription = null,
                                )
                            },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(10.dp))

        Surface(
            shape = RoundedCornerShape(SweKittyTheme.cardCornerRadiusDp.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
            modifier = Modifier.fillMaxSize(),
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
            ) { page ->
                when (ProjectTab.entries[page]) {
                    ProjectTab.Terminal -> TerminalPage(store, session)
                    ProjectTab.Chat     -> ChatPage(store, session)
                    ProjectTab.Browser  -> BrowserPage(store, session, browserMode)
                }
            }
        }
    }

    if (showInfo) {
        SessionInfoScreen(store = store, session = session, onDismiss = { showInfo = false })
    }
}

@Composable
private fun HeaderCircleButton(icon: ImageVector, contentDescription: String, onClick: () -> Unit) {
    Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f),
        modifier = Modifier.size(32.dp).clip(CircleShape).clickable(onClick = onClick),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
            Icon(icon, contentDescription = contentDescription, modifier = Modifier.size(16.dp))
        }
    }
}
