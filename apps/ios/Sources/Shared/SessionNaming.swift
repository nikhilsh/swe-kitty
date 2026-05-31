import Foundation

/// Friendly, user-facing session names. The broker mints a raw UUID as a
/// session's `name` (and often echoes that same UUID back as the broker
/// `sessionName`/`displayName` label), so naively rendering `session.name`
/// — or a broker label that's really the id — spills a UUID into the home
/// list, the history list, and project headers. That's the bug this type
/// fixes.
///
/// The resolution priority (see `SessionStore.displayName(for:)` /
/// `SessionsScreen.rowTitle`) is:
///   1. A genuine user-set custom name (never a UUID) — wins.
///   2. The first user chat message, trimmed to one ellipsized line.
///   3. A fallback of `"<agent> · <relative start time>"`.
///
/// All helpers are pure + `nonisolated static` so they can be unit-tested
/// (`SessionNamingTests`) without a live store, and reused from both the
/// live home list and the persisted history screen.
enum SessionNaming {

    /// Max characters for a chat-message-derived title before we
    /// ellipsize. ChatGPT/Claude-style short single-line label.
    static let titleBudget = 40

    /// True when `text` looks like a bare session id — a canonical
    /// 36-char hyphenated UUID (`8299a0d1-eabe-4801-9a5f-ffea9eec60f7`)
    /// or an exact match for the supplied session id. We treat both the
    /// stored `displayNames[id]` entry AND any broker-supplied label as
    /// suspect because the broker commonly sets the label to the id; a
    /// UUID-shaped string is never something the user typed, so it can
    /// never be a "custom name".
    nonisolated static func looksLikeRawID(_ text: String, sessionID: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed == sessionID { return true }
        return isUUIDLike(trimmed)
    }

    /// Canonical 8-4-4-4-12 hex UUID shape, case-insensitive.
    nonisolated static func isUUIDLike(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 5 else { return false }
        let expectedLengths = [8, 4, 4, 4, 12]
        for (part, expected) in zip(parts, expectedLengths) {
            guard part.count == expected else { return false }
            guard part.allSatisfy({ $0.isHexDigit }) else { return false }
        }
        return true
    }

    /// Collapse a chat message into a single short title line: first
    /// non-empty line, internal whitespace runs collapsed to single
    /// spaces, trimmed, then ellipsized to `titleBudget`. Returns nil for
    /// an empty/whitespace-only message so callers fall through to the
    /// agent+time fallback.
    nonisolated static func titleFromMessage(_ raw: String) -> String? {
        let firstLine = raw
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init) ?? raw
        let collapsed = firstLine
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let cleaned = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= titleBudget { return cleaned }
        return String(cleaned.prefix(titleBudget - 1)) + "…"
    }

    /// Fallback label for a session with no chat yet (terminal-only, or
    /// the transcript hasn't streamed): `"<agent> · <relative time>"`.
    /// Today → time of day ("claude · 4:02 PM"); within the last week →
    /// weekday ("claude · Mon"); older → short date. `startedAt` is an
    /// RFC3339 string; when missing/unparseable we degrade to just the
    /// agent name (never a UUID).
    nonisolated static func fallbackName(
        agent: String,
        startedAt: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let agentLabel = agent.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeAgent = agentLabel.isEmpty ? "session" : agentLabel
        guard let raw = startedAt,
              let date = parseTimestamp(raw) else {
            return safeAgent
        }
        return "\(safeAgent) · \(relativeStamp(for: date, now: now, calendar: calendar))"
    }

    /// Whole-calendar-day distance from `date` to `now` (0 = same day as
    /// `now`, 1 = the day before `now`, …). Computed against the injected
    /// `now` rather than the device clock so it's deterministic in tests —
    /// `Calendar.isDateInToday`/`isDateInYesterday` ignore any anchor and
    /// always compare to the real `Date()`, which is exactly the bug this
    /// avoids.
    nonisolated static func dayDistance(
        from date: Date,
        to now: Date,
        calendar: Calendar
    ) -> Int? {
        let startNow = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startDate, to: startNow).day
    }

    /// Human relative stamp used by the fallback name. Deterministic given
    /// an injected `now`/`calendar` so it's unit-testable.
    nonisolated static func relativeStamp(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let distance = dayDistance(from: date, to: now, calendar: calendar) ?? Int.max
        if distance <= 0 {
            // Same day as `now` (or future) → time of day.
            let f = formatter(calendar)
            f.timeStyle = .short
            f.dateStyle = .none
            return f.string(from: date)
        }
        if distance == 1 {
            return "Yesterday"
        }
        // Within the last 7 days → weekday name ("Mon").
        if distance < 7 {
            let f = formatter(calendar)
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
        let f = formatter(calendar)
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// A `DateFormatter` that honors the supplied calendar's timezone +
    /// locale so the rendered stamp is deterministic for an injected
    /// calendar (tests) and correct for the device calendar (production).
    private nonisolated static func formatter(_ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = calendar.locale ?? .current
        f.timeZone = calendar.timeZone
        return f
    }

    /// A meaningful, user-pickable cwd to surface in the UI, or nil for
    /// the ephemeral per-session scratch dir. The broker runs each
    /// session in `…/.conduit/sessions/<id>/work`, which is not a real
    /// project directory — showing it as if it were is the bug. We hide
    /// any path that lives under a `…/sessions/<…>/work` (or bare
    /// `…/sessions/<…>`) segment so only a genuine repo cwd surfaces.
    nonisolated static func meaningfulWorkingDir(_ cwd: String?) -> String? {
        guard let cwd else { return nil }
        let trimmed = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.contains(".conduit/sessions/") { return nil }
        // Generic guard for the `/sessions/<id>/work` shape regardless of
        // the leading root.
        let normalized = lower.hasSuffix("/") ? String(lower.dropLast()) : lower
        if normalized.hasSuffix("/work"),
           normalized.contains("/sessions/") {
            return nil
        }
        return trimmed
    }

    /// Tolerant RFC3339 parse — accepts the fractional-second variant the
    /// broker sometimes emits as well as the plain form.
    nonisolated static func parseTimestamp(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
