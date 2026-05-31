import Testing
import Foundation
@testable import Conduit

/// Pins the friendly-name resolution helpers. These back the home list,
/// the history list, and the project header — the rule is: NEVER render a
/// raw UUID; prefer a custom name, then the first user message, then an
/// "<agent> · <relative time>" fallback.
@Suite("SessionNaming")
struct SessionNamingTests {

    // MARK: - UUID detection

    @Test func detectsCanonicalUUID() {
        #expect(SessionNaming.isUUIDLike("8299a0d1-eabe-4801-9a5f-ffea9eec60f7"))
        #expect(SessionNaming.isUUIDLike("8299A0D1-EABE-4801-9A5F-FFEA9EEC60F7"))
    }

    @Test func rejectsNonUUIDStrings() {
        #expect(!SessionNaming.isUUIDLike("Summarize the repo"))
        #expect(!SessionNaming.isUUIDLike("feature-branch"))
        #expect(!SessionNaming.isUUIDLike("8299a0d1-eabe-4801-9a5f")) // too few groups
    }

    @Test func looksLikeRawIDCatchesIdAndUUIDAndEmpty() {
        let id = "8299a0d1-eabe-4801-9a5f-ffea9eec60f7"
        #expect(SessionNaming.looksLikeRawID(id, sessionID: id))
        #expect(SessionNaming.looksLikeRawID("plain-session-id", sessionID: "plain-session-id"))
        #expect(SessionNaming.looksLikeRawID("   ", sessionID: id))
        #expect(!SessionNaming.looksLikeRawID("My session", sessionID: id))
    }

    // MARK: - Title from message

    @Test func titleTrimsAndTakesFirstLine() {
        #expect(SessionNaming.titleFromMessage("  Summarize the repo structure  ")
            == "Summarize the repo structure")
        #expect(SessionNaming.titleFromMessage("first line\nsecond line") == "first line")
    }

    @Test func titleCollapsesInternalWhitespace() {
        #expect(SessionNaming.titleFromMessage("Fix\t the   build") == "Fix the build")
    }

    @Test func titleEllipsizesPastBudget() {
        let long = String(repeating: "a", count: 60)
        let title = SessionNaming.titleFromMessage(long)
        #expect(title?.count == SessionNaming.titleBudget)
        #expect(title?.hasSuffix("…") == true)
    }

    @Test func titleNilForEmpty() {
        #expect(SessionNaming.titleFromMessage("") == nil)
        #expect(SessionNaming.titleFromMessage("   \n  ") == nil)
    }

    // MARK: - Fallback name

    @Test func fallbackUsesTimeOfDayToday() {
        let cal = Self.utc
        let now = ISO8601DateFormatter().date(from: "2026-05-25T20:00:00Z")!
        let started = "2026-05-25T16:02:00Z"
        let name = SessionNaming.fallbackName(agent: "claude", startedAt: started, now: now, calendar: cal)
        #expect(name.hasPrefix("claude · "))
        // Time-of-day rendered in the test locale; just assert it's not a date.
        #expect(!name.contains("Mon"))
    }

    @Test func fallbackUsesWeekdayWithinWeek() {
        let cal = Self.utc
        let now = ISO8601DateFormatter().date(from: "2026-05-25T12:00:00Z")! // Monday
        let started = "2026-05-22T12:00:00Z"                                  // Friday
        let name = SessionNaming.fallbackName(agent: "codex", startedAt: started, now: now, calendar: cal)
        #expect(name == "codex · Fri")
    }

    @Test func fallbackSaysYesterday() {
        let cal = Self.utc
        let now = ISO8601DateFormatter().date(from: "2026-05-25T12:00:00Z")!
        let started = "2026-05-24T12:00:00Z"
        let name = SessionNaming.fallbackName(agent: "claude", startedAt: started, now: now, calendar: cal)
        #expect(name == "claude · Yesterday")
    }

    @Test func fallbackDegradesToAgentWhenNoTimestamp() {
        #expect(SessionNaming.fallbackName(agent: "claude", startedAt: nil) == "claude")
        #expect(SessionNaming.fallbackName(agent: "", startedAt: nil) == "session")
    }

    // MARK: - Meaningful working dir

    @Test func hidesEphemeralWorkDir() {
        #expect(SessionNaming.meaningfulWorkingDir("/root/.conduit/sessions/abc-123/work") == nil)
        #expect(SessionNaming.meaningfulWorkingDir("/var/data/sessions/xyz/work") == nil)
        #expect(SessionNaming.meaningfulWorkingDir("") == nil)
        #expect(SessionNaming.meaningfulWorkingDir(nil) == nil)
    }

    @Test func keepsRealWorkingDir() {
        #expect(SessionNaming.meaningfulWorkingDir("/Users/me/code/conduit") == "/Users/me/code/conduit")
        #expect(SessionNaming.meaningfulWorkingDir("/repo/frontend") == "/repo/frontend")
    }

    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US")
        return c
    }
}
