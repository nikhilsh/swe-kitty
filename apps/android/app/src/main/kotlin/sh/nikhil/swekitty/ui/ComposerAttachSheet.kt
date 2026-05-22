package sh.nikhil.swekitty.ui

import android.content.Context
import android.net.Uri
import android.util.Base64
import android.webkit.MimeTypeMap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import java.util.UUID

/**
 * Kinds of attachment the composer's "+" sheet offers. Pure-data enum
 * so unit tests can pin the option list without spinning up Compose.
 * Mirror of iOS `AttachKind` in `ComposerAttachSheet.swift`.
 */
enum class AttachKind {
    Image,
    File;

    val title: String get() = when (this) {
        Image -> "Attach image"
        File -> "Attach file"
    }

    val subtitle: String get() = when (this) {
        Image -> "Pick from your photo library — encoded inline as base64."
        File -> "Pick from Files — encoded inline as base64."
    }
}

/**
 * Pure-data outcome of the picker step. Stash this so ChatPage can fold
 * the encoded payload into the next outgoing chat message. Equatable
 * (data class) so tests can assert state transitions. Mirrors iOS
 * `ComposerAttachment`.
 */
data class ComposerAttachment(
    val id: String = UUID.randomUUID().toString(),
    val kind: AttachKind,
    val filename: String,
    val mimeType: String,
    val base64: String,
) {
    /**
     * Renders the attachment as a self-describing inline block — same
     * shape as iOS so brokers can reuse the same regex. The 0x01
     * binary-frame transport is a separate PR; for now everything goes
     * inline as base64.
     */
    val inlineBlock: String
        get() {
            val header = when (kind) {
                AttachKind.Image -> "[attached image: $filename; mime=$mimeType; base64]"
                AttachKind.File -> "[attached file: $filename; mime=$mimeType; base64]"
            }
            return "$header\n$base64"
        }
}

/**
 * Best-effort MIME inference from a content:// URI. Falls back to
 * application/octet-stream when both the ContentResolver and the file
 * extension map come up empty. Pulled out so tests can pin the
 * fallback (no Robolectric / Android framework needed).
 */
internal object ComposerMime {
    fun fromExtension(extension: String?): String {
        if (extension.isNullOrBlank()) return "application/octet-stream"
        val map = MimeTypeMap.getSingleton()
        return map.getMimeTypeFromExtension(extension.lowercase()) ?: "application/octet-stream"
    }

    /** Pure helper used by tests — no Android framework required. */
    fun fromExtensionOrDefault(extension: String?, fromMap: (String) -> String?): String {
        if (extension.isNullOrBlank()) return "application/octet-stream"
        return fromMap(extension.lowercase()) ?: "application/octet-stream"
    }
}

/**
 * Modal sheet driven from ChatPage's "+" button. Offers two options
 * (image, file) then dismisses. Picker work is delegated to the
 * platform `PickVisualMedia` / `OpenDocument` contracts so we never
 * touch the user's original file.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ComposerAttachSheet(
    onAttach: (ComposerAttachment) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri ->
        if (uri != null) {
            encodeUri(context, uri, AttachKind.Image)?.let {
                onAttach(it)
                onDismiss()
            }
        }
    }

    val filePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            encodeUri(context, uri, AttachKind.File)?.let {
                onAttach(it)
                onDismiss()
            }
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Attach",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )

            AttachKind.values().forEach { kind ->
                AttachRow(
                    icon = when (kind) {
                        AttachKind.Image -> Icons.Outlined.Image
                        AttachKind.File -> Icons.Outlined.AttachFile
                    },
                    title = kind.title,
                    subtitle = kind.subtitle,
                    onClick = {
                        when (kind) {
                            AttachKind.Image -> imagePicker.launch(
                                PickVisualMediaRequest(
                                    ActivityResultContracts.PickVisualMedia.ImageOnly,
                                ),
                            )
                            AttachKind.File -> filePicker.launch(arrayOf("*/*"))
                        }
                    },
                )
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun AttachRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(28.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * Resolve a picked content:// URI into a [ComposerAttachment]. Reads
 * the bytes, base64-encodes them, and looks up the display name + MIME
 * via the ContentResolver. Returns null on read failure — callers
 * keep the sheet open so the user can retry.
 */
private fun encodeUri(context: Context, uri: Uri, kind: AttachKind): ComposerAttachment? {
    val resolver = context.contentResolver
    val mime = resolver.getType(uri) ?: run {
        val ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        ComposerMime.fromExtension(ext)
    }
    val filename = queryDisplayName(context, uri) ?: uri.lastPathSegment ?: "attachment"
    val bytes = runCatching {
        resolver.openInputStream(uri)?.use { it.readBytes() }
    }.getOrNull() ?: return null
    val encoded = Base64.encodeToString(bytes, Base64.NO_WRAP)
    return ComposerAttachment(
        kind = kind,
        filename = filename,
        mimeType = mime,
        base64 = encoded,
    )
}

private fun queryDisplayName(context: Context, uri: Uri): String? {
    val cursor = context.contentResolver.query(
        uri,
        arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
        null,
        null,
        null,
    ) ?: return null
    cursor.use {
        if (it.moveToFirst()) {
            val idx = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (idx >= 0) return it.getString(idx)
        }
    }
    return null
}
