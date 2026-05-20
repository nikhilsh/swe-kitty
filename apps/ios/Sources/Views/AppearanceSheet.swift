import SwiftUI

/// Modal sheet for the Theme + Font controls, opened from
/// Settings → Appearance → Theme. Mirrors the structure of the rest
/// of Settings (uppercased mono section labels above `glassRoundedRect`
/// cards) so the two screens read the same.
struct AppearanceSheet: View {
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                SweKittyTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        themeSection
                        fontSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .tint(SweKittyTheme.accentStrong)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var themeSection: some View {
        SettingsSection(title: "Theme") {
            @Bindable var bindable = appearance
            ForEach(Array(AppearanceStore.ThemeMode.allCases.enumerated()), id: \.element.id) { idx, choice in
                SettingsPickerRow(
                    icon: icon(for: choice),
                    title: choice.label,
                    isSelected: appearance.themeMode == choice
                ) {
                    bindable.themeMode = choice
                }
                if idx < AppearanceStore.ThemeMode.allCases.count - 1 {
                    Divider().background(SweKittyTheme.separator)
                }
            }
        }
    }

    private var fontSection: some View {
        SettingsSection(title: "Chat Body Font") {
            @Bindable var bindable = appearance
            ForEach(Array(AppearanceStore.FontFamily.allCases.enumerated()), id: \.element.id) { idx, choice in
                SettingsPickerRow(
                    icon: choice == .monospaced ? "chevron.left.forwardslash.chevron.right" : "textformat",
                    title: choice.label,
                    isSelected: appearance.fontFamily == choice
                ) {
                    bindable.fontFamily = choice
                }
                if idx < AppearanceStore.FontFamily.allCases.count - 1 {
                    Divider().background(SweKittyTheme.separator)
                }
            }
        }
    }

    private func icon(for mode: AppearanceStore.ThemeMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}
