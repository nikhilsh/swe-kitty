import Foundation

// MARK: - ConduitConversationRenderer
//
// Block-level tokenizer for assistant/tool message bodies. Splits
// fenced code blocks out of markdown, collapses runs of command-shaped
// lines into a "Ran N steps" chevron, and exposes a typed
// `ToolSection` enum for the tool-card composer.
//
// Extracted verbatim from the legacy `Views/ConversationView.swift`
// (PR #69) so the ConduitChatView can drive the same markdown layout
// without dragging the legacy SwiftUI surface along. Behaviour pinned
// by `ConversationRendererTests`.

enum ConversationBlock: Equatable {
    case markdown(String)
    case code(language: String?, content: String)
    /// Collapsed tool-activity row: chevron + summary label, expands to
    /// the original tool lines. Detected from the assistant's scraped
    /// content by `ConversationRenderer.blocks` when a run of
    /// command-shaped lines appears between two prose paragraphs.
    case toolSummary(label: String, detail: String)
}

enum ToolSection: Equatable {
    case meta(ToolMetadata)
    case command(String)
    case files([ViewEventFile])
    case stdout(String)
    case stderr(String)
    case text(String)
    case code(language: String?, content: String)
    case diff(String)
}

struct ToolMetadata: Equatable {
    let exitCode: Int?
    let duration: String?
}

struct ConversationRenderer {
    static func blocks(for content: String) -> [ConversationBlock] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [ConversationBlock] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String?
        var inCode = false

        func flushMarkdown() {
            let text = markdownLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.markdown(text))
            }
            markdownLines.removeAll(keepingCapacity: true)
        }

        func flushCode() {
            let text = codeLines.joined(separator: "\n")
            if !text.isEmpty {
                blocks.append(.code(language: codeLanguage, content: text))
            }
            codeLines.removeAll(keepingCapacity: true)
            codeLanguage = nil
        }

        for line in lines {
            if line.hasPrefix("```") {
                let fence = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    flushMarkdown()
                    codeLanguage = fence.isEmpty ? nil : fence
                    inCode = true
                }
                continue
            }

            if inCode {
                codeLines.append(line)
            } else {
                markdownLines.append(line)
            }
        }

        if inCode {
            flushCode()
        } else {
            flushMarkdown()
        }

        if blocks.isEmpty {
            blocks = [.markdown(content)]
        }

        return collapseToolRuns(blocks)
    }

    /// Walks an already-tokenized markdown/code stream and groups
    /// consecutive command-shaped lines inside each `.markdown` block
    /// into a single `.toolSummary`. Detection is conservative — we
    /// only collapse when a line clearly matches a tool-call shape so
    /// regular prose with the occasional `$variable` doesn't disappear.
    static func collapseToolRuns(_ blocks: [ConversationBlock]) -> [ConversationBlock] {
        var out: [ConversationBlock] = []
        for block in blocks {
            switch block {
            case .markdown(let text):
                out.append(contentsOf: splitToolRuns(in: text))
            default:
                out.append(block)
            }
        }
        return out
    }

    private static func splitToolRuns(in text: String) -> [ConversationBlock] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [ConversationBlock] = []
        var prose: [String] = []
        var tool: [String] = []
        var toolCount = 0

        func flushProse() {
            let joined = prose.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                result.append(.markdown(joined))
            }
            prose.removeAll(keepingCapacity: true)
        }
        func flushTool() {
            guard !tool.isEmpty else { return }
            let detail = tool.joined(separator: "\n")
            let label = toolSummaryLabel(forCount: toolCount)
            result.append(.toolSummary(label: label, detail: detail))
            tool.removeAll(keepingCapacity: true)
            toolCount = 0
        }

        for line in lines {
            if isToolOutputContinuation(line, hasOpenTool: !tool.isEmpty) {
                tool.append(line)
            } else if isToolLine(line) {
                if !prose.isEmpty { flushProse() }
                tool.append(line)
                toolCount += 1
            } else {
                if !tool.isEmpty { flushTool() }
                prose.append(line)
            }
        }
        flushTool()
        flushProse()
        if result.isEmpty {
            result.append(.markdown(text))
        }
        return result
    }

    /// One-shot heuristic: a line is "tool-shaped" if it starts with a
    /// shell prompt, a recognized verb, or a path-like edit marker.
    private static func isToolLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if trimmed.hasPrefix("$ ") { return true }
        let lower = trimmed.lowercased()
        let verbs = [
            "running ", "ran ", "executing ", "reading ", "read ",
            "writing ", "wrote ", "editing ", "edited ", "listing ",
            "searching ", "checking ", "building ", "testing ",
        ]
        for v in verbs {
            if lower.hasPrefix(v) {
                let tail = trimmed.dropFirst(v.count)
                let words = tail.split(whereSeparator: { $0.isWhitespace }).count
                if words <= 3 && !tail.contains(". ") {
                    return true
                }
            }
        }
        return false
    }

    /// Lines indented under a tool block (4+ spaces or a tab) are
    /// treated as captured output and stay in the collapsed summary.
    private static func isToolOutputContinuation(_ line: String, hasOpenTool: Bool) -> Bool {
        guard hasOpenTool else { return false }
        if line.hasPrefix("    ") || line.hasPrefix("\t") { return true }
        return false
    }

    private static func toolSummaryLabel(forCount n: Int) -> String {
        switch n {
        case 1: return "Ran 1 step"
        default: return "Ran \(n) steps"
        }
    }

    static func toolSections(for event: ConversationItem) -> [ToolSection] {
        var sections: [ToolSection] = []
        let meta = extractMetadata(from: event)
        if meta.exitCode != nil || meta.duration != nil {
            sections.append(.meta(meta))
        }
        // Extract the command once so we can suppress any plain-text echo of
        // it that appears later in the content body.
        let extractedCommand = extractCommand(from: event)
        if let command = extractedCommand {
            sections.append(.command(command))
        }

        if !event.files.isEmpty {
            sections.append(.files(event.files))
        }

        let trimmed = event.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return sections
        }

        let blocks = blocks(for: trimmed)
        var currentStream: String?
        for block in blocks {
            switch block {
            case .markdown(let text):
                let lower = text.lowercased()
                if lower == "stdout:" || lower == "stdout" {
                    currentStream = "stdout"
                    continue
                }
                if lower == "stderr:" || lower == "stderr" {
                    currentStream = "stderr"
                    continue
                }
                if currentStream == "stdout" {
                    sections.append(.stdout(text))
                    currentStream = nil
                    continue
                }
                if currentStream == "stderr" {
                    sections.append(.stderr(text))
                    currentStream = nil
                    continue
                }
                // Drop single-line text blocks that are just a tool-name prefix
                // followed by the command already shown in the COMMAND card
                // (e.g. "Bash: ls -la" when the card already renders COMMAND:
                // ls -la). Only the echo is suppressed — actual output is not.
                if let cmd = extractedCommand, isCommandEcho(text, command: cmd) {
                    continue
                }
                if looksLikeDiff(text) {
                    sections.append(.diff(text))
                } else {
                    sections.append(.text(text))
                }
            case .code(let language, let content):
                if language == "diff" || looksLikeDiff(content) {
                    sections.append(.diff(content))
                } else {
                    sections.append(.code(language: language, content: content))
                }
            case .toolSummary(_, let detail):
                sections.append(.text(detail))
            }
        }
        return sections
    }

    /// Prefer the Rust classifier output where present; fall back to parsing.
    /// Keeps the iOS renderer thin per the Rust-first rule in PLAN-2026-05-19.
    static func extractMetadata(from event: ConversationItem) -> ToolMetadata {
        let fromRust = ToolMetadata(
            exitCode: event.exitCode.map { Int($0) },
            duration: event.durationMs.map { Self.formatDuration($0) }
        )
        if fromRust.exitCode != nil || fromRust.duration != nil {
            return fromRust
        }
        return extractMetadata(from: event.content)
    }

    static func extractCommand(from event: ConversationItem) -> String? {
        if let typed = event.command, !typed.isEmpty {
            return typed
        }
        return extractCommand(from: event.content)
    }

    static func formatDuration(_ ms: UInt64) -> String {
        if ms < 1_000 {
            return "\(ms)ms"
        }
        let seconds = Double(ms) / 1_000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let mins = seconds / 60.0
        return String(format: "%.1fmin", mins)
    }

    static func extractMetadata(from text: String) -> ToolMetadata {
        var exitCode: Int?
        var duration: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lower = line.lowercased()
            if lower.hasPrefix("exit code:"),
               let code = Int(line.dropFirst("exit code:".count).trimmingCharacters(in: .whitespaces)) {
                exitCode = code
            } else if lower.hasPrefix("exit="),
                      let code = Int(line.dropFirst("exit=".count).trimmingCharacters(in: .whitespaces)) {
                exitCode = code
            } else if lower.hasPrefix("duration:") {
                duration = String(line.dropFirst("duration:".count)).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("took ") {
                duration = String(line.dropFirst("took ".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ToolMetadata(exitCode: exitCode, duration: duration)
    }

    static func looksLikeDiff(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return false }
        return lines.contains(where: { $0.hasPrefix("+") || $0.hasPrefix("-") || $0.hasPrefix("@@") })
    }

    static func extractCommand(from text: String) -> String? {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("$ ") {
                return String(line.dropFirst(2))
            }
            if line.lowercased().hasPrefix("running ") {
                return String(line.dropFirst("running ".count))
            }
            if line.lowercased().hasPrefix("cmd:") {
                return String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Returns `true` when `text` is a single-line command-echo that
    /// duplicates the COMMAND card already shown in the tool card header.
    /// Patterns: `<ToolName>: <cmd>`, `Bash: <cmd>`, `Tool: <cmd>`.
    /// Matching is case-insensitive; only suppresses single-line blocks
    /// so multi-line output is never dropped.
    static func isCommandEcho(_ text: String, command: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count == 1 else { return false }
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalCmd = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let colonRange = line.range(of: ": ") {
            let suffix = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if suffix == normalCmd { return true }
        }
        return false
    }

    static func extractPendingOptions(from text: String) -> [String] {
        var opts: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let value = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty && !opts.contains(value) { opts.append(value) }
                continue
            }
            if line.lowercased().hasPrefix("option:") {
                let value = String(line.dropFirst("option:".count)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty && !opts.contains(value) { opts.append(value) }
            }
        }
        return Array(opts.prefix(4))
    }
}

// MARK: - Structured markdown

/// One renderable piece of a `.markdown` block, after splitting on
/// block boundaries that `AttributedString(markdown:)` collapses.
///
/// Why this exists: `AttributedString(markdown: ..., interpretedSyntax:
/// .full)` interprets *inline* syntax (bold / links / code spans) but
/// flattens *block* structure — paragraphs, list items and headings are
/// concatenated with no vertical separation, and GFM tables are emitted
/// as their cell text run together with no row/column structure. On a
/// narrow phone that reads as the "SessionAssistantNotes062e…" run-on
/// the device bug reported. We pre-split the markdown into these typed
/// blocks here (pure function, unit-testable) and render each with its
/// own vertical rhythm in `ConduitStructuredMarkdownView`, so headings
/// get weight + space, lists get bullets + indent, and tables render as
/// stacked records instead of one concatenated string.
enum ConduitMarkdownPiece: Equatable {
    /// `# … ######` — `level` is 1...6, `text` is the heading body
    /// (markers stripped). Rendered larger/bold with space above/below.
    case heading(level: Int, text: String)
    /// A run of prose lines (a paragraph). `text` keeps soft line
    /// breaks; inline markdown is interpreted at render time.
    case paragraph(String)
    /// An unordered (`-`/`*`/`+`) or ordered (`1.`) list. Each item is
    /// the text after the marker; `ordered` picks bullet vs. number.
    case list(ordered: Bool, items: [String])
    /// A GFM pipe table: `headers` is the first row, `rows` the body
    /// rows (the `---|---` separator row is dropped). Rendered as
    /// stacked "header: value" records, robust on a narrow phone.
    case table(headers: [String], rows: [[String]])
    /// A fenced code block. For SETTLED messages fences are split out
    /// upstream by `ConversationRenderer.blocks`, so `parse` never sees
    /// one — but the STREAMING path feeds the live buffer straight in, so
    /// `parse` handles an opening ``` (even still-unclosed mid-stream) and
    /// emits this instead of leaking the raw fence markers as prose
    /// (device feedback v0.0.50 #6).
    case code(language: String?, content: String)
}

enum ConduitMarkdownStructure {

    /// Split a markdown string into typed pieces on block boundaries. The
    /// output never concatenates two logical blocks: headings, paragraphs,
    /// lists, tables and fenced code each become their own piece so the
    /// renderer can space them. Settled messages arrive code-free (fences
    /// pre-split by `ConversationRenderer.blocks`); the streaming path
    /// passes the live buffer in raw, so fences are handled here too.
    static func parse(_ markdown: String) -> [ConduitMarkdownPiece] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var pieces: [ConduitMarkdownPiece] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { pieces.append(.paragraph(text)) }
            paragraph.removeAll(keepingCapacity: true)
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line — paragraph boundary.
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Fenced code block (streaming path only — settled messages
            // arrive pre-split). Consume the body up to the closing ```;
            // if the fence is still open (mid-stream), consume to the end
            // and emit what we have so far as a code block rather than
            // leaking the raw ``` marker + reflowed code as prose.
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1 // consume the closing fence
                        break
                    }
                    code.append(lines[i])
                    i += 1
                }
                pieces.append(.code(language: lang.isEmpty ? nil : lang,
                                    content: code.joined(separator: "\n")))
                continue
            }

            // Heading (#, ##, … up to ######).
            if let heading = parseHeading(trimmed) {
                flushParagraph()
                pieces.append(.heading(level: heading.level, text: heading.text))
                i += 1
                continue
            }

            // GFM table: a pipe row immediately followed by a
            // delimiter row (`| --- | :--: |`). We need the lookahead
            // so a lone `a | b` prose line isn't mistaken for a table.
            if isTableRow(trimmed), i + 1 < lines.count,
               isTableDelimiter(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                flushParagraph()
                let (table, consumed) = parseTable(lines, startingAt: i)
                pieces.append(table)
                i += consumed
                continue
            }

            // List (unordered or ordered) — consume the contiguous run.
            if listMarker(trimmed) != nil {
                flushParagraph()
                let (list, consumed) = parseList(lines, startingAt: i)
                pieces.append(list)
                i += consumed
                continue
            }

            // Otherwise accumulate into the current paragraph.
            paragraph.append(line)
            i += 1
        }
        flushParagraph()

        if pieces.isEmpty {
            // Preserve the documented "always at least one piece"
            // contract so an all-whitespace block still renders.
            pieces.append(.paragraph(markdown.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return pieces
    }

    // MARK: Heading

    private static func parseHeading(_ trimmed: String) -> (level: Int, text: String)? {
        guard trimmed.hasPrefix("#") else { return nil }
        var level = 0
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex, trimmed[idx] == "#", level < 6 {
            level += 1
            idx = trimmed.index(after: idx)
        }
        guard level >= 1 else { return nil }
        // ATX headings require a space (or end of line) after the run
        // of `#` — `#foo` (no space) is not a heading.
        let rest = String(trimmed[idx...])
        guard rest.isEmpty || rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return (level, text)
    }

    // MARK: List

    /// Returns the marker prefix length if `trimmed` opens a list item
    /// (`- `, `* `, `+ `, or `<n>. `), else nil.
    private static func listMarker(_ trimmed: String) -> (ordered: Bool, contentStart: String.Index)? {
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return (false, trimmed.index(trimmed.startIndex, offsetBy: 2))
        }
        // Ordered: leading digits then `. ` or `) `.
        var idx = trimmed.startIndex
        var sawDigit = false
        while idx < trimmed.endIndex, trimmed[idx].isNumber {
            sawDigit = true
            idx = trimmed.index(after: idx)
        }
        if sawDigit, idx < trimmed.endIndex,
           trimmed[idx] == "." || trimmed[idx] == ")" {
            let after = trimmed.index(after: idx)
            if after < trimmed.endIndex, trimmed[after] == " " {
                return (true, trimmed.index(after: after))
            }
        }
        return nil
    }

    private static func parseList(_ lines: [String], startingAt start: Int) -> (ConduitMarkdownPiece, Int) {
        var items: [String] = []
        var ordered = false
        var i = start
        var first = true
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard let marker = listMarker(trimmed) else { break }
            if first { ordered = marker.ordered; first = false }
            let item = String(trimmed[marker.contentStart...]).trimmingCharacters(in: .whitespaces)
            items.append(item)
            i += 1
        }
        return (.list(ordered: ordered, items: items), i - start)
    }

    // MARK: Table

    private static func isTableRow(_ trimmed: String) -> Bool {
        trimmed.contains("|")
    }

    /// A GFM delimiter row is all `|`, `-`, `:` and whitespace, with at
    /// least one `-`.
    private static func isTableDelimiter(_ trimmed: String) -> Bool {
        guard trimmed.contains("-") else { return false }
        return trimmed.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
    }

    private static func splitRow(_ row: String) -> [String] {
        var cells = row.trimmingCharacters(in: .whitespaces)
        // Drop the optional leading/trailing pipe so a `| a | b |` row
        // doesn't produce empty edge cells.
        if cells.hasPrefix("|") { cells.removeFirst() }
        if cells.hasSuffix("|") { cells.removeLast() }
        return cells.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseTable(_ lines: [String], startingAt start: Int) -> (ConduitMarkdownPiece, Int) {
        let headers = splitRow(lines[start])
        var rows: [[String]] = []
        var i = start + 2 // skip header + delimiter
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard isTableRow(trimmed), !trimmed.isEmpty else { break }
            rows.append(splitRow(lines[i]))
            i += 1
        }
        return (.table(headers: headers, rows: rows), i - start)
    }
}

// MARK: - Diff parser

struct ConversationDiffFile: Identifiable {
    let id: String
    let path: String
    let lines: [String]
}

enum ConversationDiffParser {
    static func files(from content: String) -> [ConversationDiffFile] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var files: [ConversationDiffFile] = []
        var currentPath = "patch.diff"
        var bucket: [String] = []

        func flush() {
            if !bucket.isEmpty {
                files.append(ConversationDiffFile(id: "\(currentPath)-\(files.count)", path: currentPath, lines: bucket))
                bucket.removeAll(keepingCapacity: true)
            }
        }

        for line in lines {
            if line.hasPrefix("diff --git ") {
                flush()
                currentPath = parsePath(from: line)
                bucket.append(line)
                continue
            }
            bucket.append(line)
        }
        flush()
        return files.isEmpty ? [ConversationDiffFile(id: "patch", path: "patch.diff", lines: lines)] : files
    }

    private static func parsePath(from diffLine: String) -> String {
        let parts = diffLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 4 else { return "patch.diff" }
        let raw = String(parts[3])
        if raw.hasPrefix("b/") {
            return String(raw.dropFirst(2))
        }
        return raw
    }
}

// MARK: - Timestamp helpers

enum ConversationTimestamp {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ rawTimestamp: String) -> String {
        let trimmed = rawTimestamp.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        guard let date = iso.date(from: trimmed) ?? isoNoFrac.date(from: trimmed) else {
            return trimmed
        }
        return Self.relative.localizedString(for: date, relativeTo: Date())
    }
}
