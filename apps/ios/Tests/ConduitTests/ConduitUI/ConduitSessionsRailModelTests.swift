import Testing
import Foundation
@testable import Conduit

/// Pins down the rail's row contract. The rail is the iPad sidebar
/// flavor of the home screen — it must surface every session row and
/// highlight whichever id matches `selectedSessionID`. The SwiftUI
/// view is a thin renderer over these rows.
@Suite("ConduitUI.SessionsRailModel")
struct ConduitSessionsRailModelTests {

    @Test func rowsEmptyOnEmptySnapshot() {
        let snap = ConduitUI.HomeSnapshot.empty
        #expect(ConduitUI.SessionsRailModel.rows(snap).isEmpty)
    }

    @Test func rowsCountMatchesSessionCount() {
        let snap = ConduitUI.HomeSnapshot(
            harness: .live,
            sessions: [
                ConduitUI.HomeSnapshotSession(id: "a", displayName: "A", assistant: "claude", phase: nil),
                ConduitUI.HomeSnapshotSession(id: "b", displayName: "B", assistant: "claude", phase: nil),
                ConduitUI.HomeSnapshotSession(id: "c", displayName: "C", assistant: "claude", phase: nil),
            ],
            placeholders: [],
            selectedSessionID: nil,
            endpointDisplayHost: "host"
        )
        #expect(ConduitUI.SessionsRailModel.rows(snap).count == 3)
    }

    @Test func activeSessionRowIsHighlighted() {
        let snap = ConduitUI.HomeSnapshot(
            harness: .live,
            sessions: [
                ConduitUI.HomeSnapshotSession(id: "a", displayName: "A", assistant: "claude", phase: nil),
                ConduitUI.HomeSnapshotSession(id: "b", displayName: "B", assistant: "claude", phase: nil),
                ConduitUI.HomeSnapshotSession(id: "c", displayName: "C", assistant: "claude", phase: nil),
            ],
            placeholders: [],
            selectedSessionID: "b",
            endpointDisplayHost: "host"
        )
        let rows = ConduitUI.SessionsRailModel.rows(snap)
        #expect(rows.map(\.isSelected) == [false, true, false])
    }

    @Test func noRowHighlightedWhenSelectedIDMissing() {
        // Stale or never-set selection — every row should render
        // unhighlighted (no accidental "first row is selected"
        // fallback).
        let snap = ConduitUI.HomeSnapshot(
            harness: .live,
            sessions: [
                ConduitUI.HomeSnapshotSession(id: "a", displayName: "A", assistant: "claude", phase: nil),
                ConduitUI.HomeSnapshotSession(id: "b", displayName: "B", assistant: "claude", phase: nil),
            ],
            placeholders: [],
            selectedSessionID: "ghost",
            endpointDisplayHost: nil
        )
        let rows = ConduitUI.SessionsRailModel.rows(snap)
        #expect(rows.allSatisfy { $0.isSelected == false })
    }
}
