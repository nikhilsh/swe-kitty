import SwiftUI

/// Standard health/state dot used in lists and headers.
struct HealthDot: View {
    let health: String
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(ConduitTheme.border.opacity(0.45), lineWidth: 0.5)
            )
            .accessibilityLabel("health: \(health)")
    }

    private var color: Color {
        switch health {
        case "green":  return ConduitTheme.success
        case "yellow": return ConduitTheme.warning
        case "red":    return ConduitTheme.danger
        default:       return ConduitTheme.textMuted
        }
    }
}

/// Inline error banner — used by ProjectListView for session-creation failures
/// and elsewhere for non-fatal harness errors.
struct InlineErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ConduitTheme.danger)
            Text(message)
                .font(.footnote)
                .foregroundStyle(ConduitTheme.textBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ConduitTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassRect(cornerRadius: ConduitTheme.smallCornerRadius, tint: ConduitTheme.danger.opacity(0.35))
    }
}

/// Pill that summarises the current HarnessState. Distinct from session
/// health — this is "can we talk to the server at all."
struct HarnessBadge: View {
    let state: HarnessState

    var body: some View {
        HStack(spacing: 6) {
            indicator
            Text(state.badgeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ConduitTheme.textBody)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCapsule(tint: tint)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .connecting, .reconnecting:
            ProgressView().controlSize(.mini)
        case .live:
            HealthDot(health: "green", size: 8)
        case .linked:
            HealthDot(health: "yellow", size: 8)
        case .failed:
            HealthDot(health: "red", size: 8)
        case .disconnected:
            HealthDot(health: "unknown", size: 8)
        }
    }

    private var tint: Color? {
        switch state {
        case .live:         return ConduitTheme.success.opacity(0.35)
        case .linked:       return ConduitTheme.warning.opacity(0.30)
        case .reconnecting: return ConduitTheme.warning.opacity(0.35)
        case .failed:       return ConduitTheme.danger.opacity(0.35)
        case .connecting:   return ConduitTheme.accent.opacity(0.30)
        case .disconnected: return nil
        }
    }
}
