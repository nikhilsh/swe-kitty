import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen + Dynamic Island renderer for the active-turn Live Activity.
///
/// The state shape (`TurnActivityAttributes` / `ContentState`) is compiled
/// into both this extension and the host app — see
/// `Sources/Models/TurnActivityAttributes.swift`. The host calls
/// `Activity<TurnActivityAttributes>.request(...)` from
/// `TurnLiveActivityController`; iOS routes the updates here.
///
/// **Why no `SweKittyTheme` import?**
/// Widget extensions get a separate bundle and don't share the host's
/// asset catalog without an extra Settings.bundle + shared-resources
/// dance. We keep this view file self-contained with system colors so
/// the extension target's Swift module has zero host-side dependencies
/// beyond the two shared model files.
struct TurnLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TurnActivityAttributes.self) { context in
            // Lock-screen / banner presentation.
            TurnLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: 4 regions. Leading = health dot, trailing =
                // elapsed, center = current tool/command, bottom = cancel.
                DynamicIslandExpandedRegion(.leading) {
                    HealthDotView(status: context.state.status)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedView(startedAt: context.state.startedAt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(displayLabel(state: context.state) ?? context.attributes.agentName)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Tapping the cancel surface deep-links back into the
                    // app via the existing `swekitty://` scheme so the
                    // user lands on the live session. The harness-level
                    // "cancel" verb is the app's job; the widget only
                    // ferries intent.
                    Link(destination: cancelURL(sessionID: context.attributes.sessionID)) {
                        Label("Open session", systemImage: "arrow.up.right.square")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "play.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                ElapsedView(startedAt: context.state.startedAt, compact: true)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            } minimal: {
                Image(systemName: "play.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func displayLabel(state: TurnActivityAttributes.ContentState) -> String? {
        if let command = state.currentCommand, !command.isEmpty { return command }
        if let tool = state.currentTool, !tool.isEmpty { return tool }
        return nil
    }

    private func cancelURL(sessionID: String) -> URL {
        // Matches `CFBundleURLSchemes: [swekitty]` registered by the host
        // app in `Sources/Info.plist`. The app side decides what to do
        // with the path — today it just brings the session to focus.
        URL(string: "swekitty://session/\(sessionID)") ?? URL(string: "swekitty://")!
    }
}

// MARK: - Lock-screen view

/// Single-card layout for the lock screen + StandBy.
///
/// Three rows, top-down:
///   1. health dot + agent name + status pill
///   2. current tool / command (mono, truncated)
///   3. elapsed clock + token counts
private struct TurnLockScreenView: View {
    let attributes: TurnActivityAttributes
    let state: TurnActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HealthDotView(status: state.status)
                Text(attributes.agentName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(state.status.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(commandLine)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 12) {
                ElapsedView(startedAt: state.startedAt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("↓\(state.tokensIn)  ↑\(state.tokensOut)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var commandLine: String {
        if let command = state.currentCommand, !command.isEmpty { return command }
        if let tool = state.currentTool, !tool.isEmpty { return tool }
        return "…"
    }
}

// MARK: - Subviews

/// Tiny status-coloured dot mirroring the host app's `HealthDot` without
/// pulling in `SweKittyTheme`. Status strings come from
/// `TurnActivityContentState.status` — "running" / "pending" / "exited".
private struct HealthDotView: View {
    let status: String

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().stroke(.white.opacity(0.25), lineWidth: 0.5)
            )
            .accessibilityLabel("status: \(status)")
    }

    private var color: Color {
        switch status {
        case "running": return .green
        case "pending": return .yellow
        case "exited":  return .gray
        default:        return .blue
        }
    }
}

/// Live-updating elapsed-time label.
///
/// Uses `Text(_:style:)` so WidgetKit ticks the label without us pushing
/// a fresh `ContentState` every second — that's the documented way to
/// animate time in a Live Activity.
private struct ElapsedView: View {
    let startedAt: Date
    var compact: Bool = false

    var body: some View {
        if compact {
            Text(startedAt, style: .timer)
                .monospacedDigit()
        } else {
            Text(startedAt, style: .relative)
                .monospacedDigit()
        }
    }
}
