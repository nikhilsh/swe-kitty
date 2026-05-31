import SwiftUI
import WidgetKit

/// Widget extension entry point.
///
/// The `@main` `WidgetBundle` is the contract WidgetKit uses to enumerate
/// every widget / Live Activity this extension ships. Today we only have
/// one (`TurnLiveActivity`) — when we add lock-screen complications or a
/// home-screen widget they slot in here without a new extension target.
@main
struct ConduitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TurnLiveActivity()
    }
}
