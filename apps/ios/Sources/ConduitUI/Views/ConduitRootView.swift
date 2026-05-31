import SwiftUI

// MARK: - ConduitRootView
//
// Top-level shell for the ConduitUI tree — the single production root
// after the litter-ui-cutover (PR #119 deleted the legacy `RootView`
// + its dependents).
//
// We branch on `horizontalSizeClass`:
//   - `.compact` (iPhone): the existing iPhone surface
//     (`ConduitUI.HomeView`, which owns its own `NavigationStack`
//     + bottom action bar).
//   - `.regular` (iPad / large screen): `NavigationSplitView` with a
//     `ConduitUI.SessionsRail` sidebar + `ConduitUI.ProjectView`
//     detail. Empty detail when nothing's selected.
//
// Per PLAN-LITTER-UI Decisions row 3: iPad keeps NavigationSplitView,
// the iPhone bottom bar is iPhone-shape only. The rail is the
// sidebar variant of HomeView (no bottom bar; sessions tap drives
// `SessionStore.switchTo(sessionID:)` which the detail observes).

extension ConduitUI {

    struct RootView: View {
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass

        var body: some View {
            ZStack {
                ConduitUI.Palette.surface.color
                    // `.container` (not a bare ignore) so the root canvas never
                    // claims the `.keyboard` region — see GlassAppBackground.
                    .ignoresSafeArea(.container, edges: .all)
                if horizontalSizeClass == .regular {
                    TabletShell()
                } else {
                    ConduitUI.HomeView()
                }
            }
        }
    }

    // MARK: - TabletShell (iPad / regular size class)
    //
    // The design's tablet IDE chrome: a far-left activity bar +
    // section content. Home / Sessions render inline; History / Boxes /
    // Settings present as sheets (reusing the existing sheet views)
    // until they get dedicated tablet layouts. Section choice persists
    // under `nk_tab_section` (matches the prototype key).

    fileprivate struct TabletShell: View {
        @Environment(SessionStore.self) private var store
        @Environment(\.neonTheme) private var neon
        @AppStorage("nk_tab_section") private var sectionRaw =
            ConduitUI.TabletSection.sessions.rawValue

        private var section: ConduitUI.TabletSection {
            ConduitUI.TabletSection(rawValue: sectionRaw) ?? .sessions
        }

        var body: some View {
            HStack(spacing: 0) {
                ConduitUI.TabletActivityBar(section: section) { picked in
                    sectionRaw = picked.rawValue
                }
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        @ViewBuilder private var sectionContent: some View {
            switch section {
            case .home:
                ConduitUI.TabletHome { id in
                    store.selectedSessionID = id
                    sectionRaw = ConduitUI.TabletSection.sessions.rawValue
                }
            case .settings:
                ConduitUI.SettingsView(embedded: true)
            case .boxes:
                ConduitUI.DiscoveryView(embedded: true)
            case .history:
                SessionSearchView(
                    onSelect: { id in
                        store.selectedSessionID = id
                        sectionRaw = ConduitUI.TabletSection.sessions.rawValue
                    },
                    embedded: true
                )
            default:
                sessionsSplit
            }
        }

        private var sessionsSplit: some View {
            @Bindable var store = store
            return NavigationSplitView {
                ConduitUI.SessionsRail()
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
                    .toolbar(.hidden, for: .navigationBar)
            } detail: {
                if let id = store.selectedSessionID,
                   let session = store.sessions.first(where: { $0.id == id }) {
                    // Tablet 3-pane (design's TabletSessionView): chat-only
                    // centre + a right pane with Terminal / Browser / Info
                    // tabs. ProjectView(chatOnly:) drops its own tab strip;
                    // the right pane reuses the same terminal/browser/info
                    // surfaces. Phone uses ProjectView's full tabs (chatOnly
                    // defaults false).
                    HStack(spacing: 0) {
                        ConduitUI.ProjectView(session: session, chatOnly: true)
                            // Keying on session id forces SwiftUI to
                            // discard the previous detail's `@State`
                            // when the user picks a different session.
                            .id(session.id)
                        Divider().background(neon.border)
                        ConduitUI.TabletRightPane(session: session)
                            .frame(width: 392)
                            .id(session.id)
                    }
                } else {
                    ConduitUI.EmptyDetail()
                }
            }
            .neonAccentTint()
        }
    }
}
