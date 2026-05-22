import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
/// ActivityKit-facing attributes for the turn Live Activity.
///
/// Mirrors `TurnActivityAttributesData` / `TurnActivityContentState` from
/// the pure model so the same shape ships through the system. Split into
/// its own file (separate from `TurnLiveActivityController`) so the widget
/// extension target can compile this declaration without also pulling in
/// the controller class — which transitively references `SessionStore`,
/// `ConversationItem`, and other host-only types.
///
/// Both the main app target and the `SweKittyWidgets` extension target
/// include this source file (see `apps/ios/project.yml`) so the generic
/// `Activity<TurnActivityAttributes>` resolves to the same concrete type
/// on both sides of the system boundary — that's the contract iOS uses
/// to route lock-screen / Dynamic Island updates to the right widget.
public struct TurnActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentTool: String?
        public var currentCommand: String?
        public var startedAt: Date
        public var tokensIn: Int
        public var tokensOut: Int
        public var status: String

        public init(from state: TurnActivityContentState) {
            self.currentTool = state.currentTool
            self.currentCommand = state.currentCommand
            self.startedAt = state.startedAt
            self.tokensIn = state.tokensIn
            self.tokensOut = state.tokensOut
            self.status = state.status
        }

        public init(
            currentTool: String? = nil,
            currentCommand: String? = nil,
            startedAt: Date,
            tokensIn: Int = 0,
            tokensOut: Int = 0,
            status: String = "running"
        ) {
            self.currentTool = currentTool
            self.currentCommand = currentCommand
            self.startedAt = startedAt
            self.tokensIn = tokensIn
            self.tokensOut = tokensOut
            self.status = status
        }
    }

    public var agentName: String
    public var sessionID: String

    public init(from data: TurnActivityAttributesData) {
        self.agentName = data.agentName
        self.sessionID = data.sessionID
    }

    public init(agentName: String, sessionID: String) {
        self.agentName = agentName
        self.sessionID = sessionID
    }
}
#endif
