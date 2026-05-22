package sh.nikhil.swekitty.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-data assertions for the composer attach sheet. Mirror of iOS
 * `ComposerAttachSheetModelTests`. Runs under plain JUnit — no
 * Robolectric, no Compose runtime, no Android framework.
 */
class ComposerAttachModelTest {

    @Test fun attachKinds_orderedImageThenFile() {
        // The bottom-sheet renders one row per AttachKind in declaration
        // order — iOS leads with image, Android matches. Locking the
        // order here prevents an accidental swap that would silently
        // change the default attach affordance.
        val kinds = AttachKind.values().toList()
        assertEquals(listOf(AttachKind.Image, AttachKind.File), kinds)
    }

    @Test fun titles_matchIOSCopy() {
        assertEquals("Attach image", AttachKind.Image.title)
        assertEquals("Attach file", AttachKind.File.title)
    }

    @Test fun subtitles_mentionInlineBase64() {
        // Subtitle copy is user-facing — both rows promise the file gets
        // encoded inline as base64. If we ever swap to the 0x01 binary
        // frame transport (other parallel PR), update both surfaces in
        // lockstep.
        assertTrue(AttachKind.Image.subtitle.contains("base64"))
        assertTrue(AttachKind.File.subtitle.contains("base64"))
    }

    @Test fun mimeFallback_emptyExtension() {
        // ComposerMime.fromExtensionOrDefault is the pure variant so we
        // don't have to spin up MimeTypeMap (which needs Android). Empty
        // extension → octet-stream, matching iOS UTType behaviour.
        assertEquals(
            "application/octet-stream",
            ComposerMime.fromExtensionOrDefault(null) { null },
        )
        assertEquals(
            "application/octet-stream",
            ComposerMime.fromExtensionOrDefault("") { null },
        )
    }

    @Test fun mimeFallback_unknownExtension() {
        // Unknown extension that the map can't classify → octet-stream.
        // The lookup is case-folded to lowercase so HEIC and heic both
        // resolve identically.
        assertEquals(
            "application/octet-stream",
            ComposerMime.fromExtensionOrDefault("xyzunknown") { null },
        )
    }

    @Test fun mimeFallback_knownExtension() {
        // When the underlying map returns something, we surface it
        // unchanged. The lambda receives the lowercased extension.
        val fake: (String) -> String? = { ext -> if (ext == "pdf") "application/pdf" else null }
        assertEquals("application/pdf", ComposerMime.fromExtensionOrDefault("PDF", fake))
        assertEquals("application/pdf", ComposerMime.fromExtensionOrDefault("pdf", fake))
    }

    @Test fun inlineBlock_imageFormatMatchesIOSRegex() {
        // Same wire format as the iOS composer — brokers reuse one
        // regex to parse the inline header. Two-line layout: header
        // line, then the base64 payload.
        val att = ComposerAttachment(
            id = "fixed-id",
            kind = AttachKind.Image,
            filename = "IMG_0123.HEIC",
            mimeType = "image/jpeg",
            base64 = "ZmFrZS1ieXRlcw==",
        )
        val block = att.inlineBlock
        assertEquals(
            "[attached image: IMG_0123.HEIC; mime=image/jpeg; base64]\nZmFrZS1ieXRlcw==",
            block,
        )
        // Regex matches the litter web composer pattern: "[attached
        // <kind>: <filename>; mime=<mime>; base64]\n<payload>".
        val regex = Regex("^\\[attached (image|file): (.+); mime=([^;]+); base64]\n(.*)\$")
        val match = regex.find(block)
        assertNotNull("inlineBlock must match the cross-surface regex", match)
        assertEquals("image", match!!.groupValues[1])
        assertEquals("IMG_0123.HEIC", match.groupValues[2])
        assertEquals("image/jpeg", match.groupValues[3])
        assertEquals("ZmFrZS1ieXRlcw==", match.groupValues[4])
    }

    @Test fun inlineBlock_fileFormatMatchesIOSRegex() {
        val att = ComposerAttachment(
            id = "fixed-id",
            kind = AttachKind.File,
            filename = "spec.pdf",
            mimeType = "application/pdf",
            base64 = "JVBERi0=",
        )
        val block = att.inlineBlock
        assertEquals(
            "[attached file: spec.pdf; mime=application/pdf; base64]\nJVBERi0=",
            block,
        )
        val regex = Regex("^\\[attached (image|file): (.+); mime=([^;]+); base64]\n(.*)\$")
        val match = regex.find(block)
        assertNotNull(match)
        assertEquals("file", match!!.groupValues[1])
    }

    @Test fun composeOutgoingMessage_attachmentsAppendedAfterDraft() {
        val draft = "please review"
        val att = ComposerAttachment(
            id = "a",
            kind = AttachKind.File,
            filename = "spec.pdf",
            mimeType = "application/pdf",
            base64 = "AAA=",
        )
        val msg = composeOutgoingMessage(
            draft = draft,
            pinnedContexts = emptyList(),
            pendingAttachments = listOf(att),
        )
        assertTrue(msg.startsWith("please review"))
        assertTrue(msg.contains("[attached file: spec.pdf; mime=application/pdf; base64]"))
        assertTrue(msg.endsWith("AAA="))
    }

    @Test fun composeOutgoingMessage_emptyDraftAndNothingPinned_returnsEmpty() {
        // Nothing pinned + empty draft + no attachments → empty string.
        // The composer's send path treats that as a no-op.
        val msg = composeOutgoingMessage(
            draft = "   ",
            pinnedContexts = emptyList(),
            pendingAttachments = emptyList(),
        )
        assertEquals("", msg)
    }
}
