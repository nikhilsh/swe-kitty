import Testing
@testable import Conduit

/// Composer placeholder + Unicode ellipsis assertions. The legacy
/// `ChatTab` view was deleted in the upstream-ui-cutover; the same
/// "Message <agent>…" rule is now expressed by
/// `ConduitUI.ChatViewModel.composerPlaceholder(forAgent:)`. Tests are
/// retargeted onto that surface so the rule keeps its anti-regression
/// pin without depending on a deleted view.
@Suite("ConduitChatView.composerPlaceholder")
struct ChatTabComposerTests {
    @Test func placeholderUsesActiveAgentName() {
        #expect(
            ConduitUI.ChatViewModel.composerPlaceholder(forAgent: "claude")
            == "Message claude\u{2026}"
        )
    }

    @Test func placeholderHandlesOtherAgents() {
        #expect(
            ConduitUI.ChatViewModel.composerPlaceholder(forAgent: "codex")
            == "Message codex\u{2026}"
        )
    }

    @Test func placeholderFallsBackOnEmptyAssistant() {
        // Sessions that haven't received a status frame yet may have
        // an empty assistant string. The composer still needs to
        // render *something* legible.
        #expect(ConduitUI.ChatViewModel.composerPlaceholder(forAgent: "") == "Message\u{2026}")
        #expect(ConduitUI.ChatViewModel.composerPlaceholder(forAgent: nil) == "Message\u{2026}")
    }

    @Test func placeholderUsesUnicodeHorizontalEllipsis() {
        // upstream uses the single-codepoint "…" (U+2026), not three
        // ASCII dots. The visual is subtly different and the spec
        // calls it out — make sure we don't regress to "...".
        let placeholder = ConduitUI.ChatViewModel.composerPlaceholder(forAgent: "claude")
        #expect(placeholder.last == "\u{2026}")
        #expect(!placeholder.hasSuffix("..."))
    }
}
