import Testing
@testable import Conduit

/// Pins `ConduitUI.ForkOptions.models(forAssistant:)` + `modelLabel` /
/// `inheritModel`. The fork sheet's model dropdown is built straight off
/// these pure lists, and the broker passes the chosen value to the
/// agent's --model flag — so the per-assistant filtering and the
/// inherit→no-override mapping are a contract worth pinning. Mirror of
/// Android `ForkModelOptionsTest`.
@Suite("ConduitUI.ForkOptions.models")
struct ConduitForkOptionsTests {

    @Test func claudeOffersInheritThenAliases() {
        let models = ConduitUI.ForkOptions.models(forAssistant: "claude")
        #expect(models == [ConduitUI.ForkOptions.inheritModel, "opus", "sonnet", "haiku"])
        // The leading entry is the inherit sentinel (no override).
        #expect(models.first == ConduitUI.ForkOptions.inheritModel)
    }

    @Test func codexOffersInheritThenCodexAlias() {
        let models = ConduitUI.ForkOptions.models(forAssistant: "codex")
        #expect(models == [ConduitUI.ForkOptions.inheritModel, "gpt-5-codex", "gpt-5", "gpt-5.5"])
    }

    @Test func unknownAssistantOnlyOffersInherit() {
        let models = ConduitUI.ForkOptions.models(forAssistant: "gemini")
        #expect(models == [ConduitUI.ForkOptions.inheritModel])
    }

    @Test func optionsAreFilteredByAssistant() {
        // claude aliases never leak into codex's list and vice-versa.
        let claude = ConduitUI.ForkOptions.models(forAssistant: "claude")
        let codex = ConduitUI.ForkOptions.models(forAssistant: "codex")
        #expect(claude.contains("opus"))
        #expect(!codex.contains("opus"))
        #expect(codex.contains("gpt-5-codex"))
        #expect(!claude.contains("gpt-5-codex"))
    }

    @Test func inheritModelIsTheEmptyNoOverrideSentinel() {
        // The sheet sends `model.isEmpty ? nil : model` to forkSession,
        // so the inherit option must be the empty string for an untouched
        // fork to carry no --model override.
        #expect(ConduitUI.ForkOptions.inheritModel == "")
    }

    @Test func modelLabelRendersInheritAsDefaultAndAliasesVerbatim() {
        #expect(ConduitUI.ForkOptions.modelLabel(ConduitUI.ForkOptions.inheritModel) == "Default (inherit)")
        #expect(ConduitUI.ForkOptions.modelLabel("") == "Default (inherit)")
        #expect(ConduitUI.ForkOptions.modelLabel("opus") == "opus")
        #expect(ConduitUI.ForkOptions.modelLabel("gpt-5-codex") == "gpt-5-codex")
    }
}
