import UIKit

/// Custom keyboard accessory bar for the terminal view. Claude/Codex
/// TUIs are nearly unusable on touch without Esc/Tab/Ctrl/arrows; the
/// iOS soft keyboard provides none of those by default. This bar sits
/// above the keyboard via `WKWebView.inputAccessoryView` (see
/// `KeyableWKWebView`).
///
/// Termius-style: a horizontally-scrolling row of rounded key caps,
/// hosted in a `UIInputView` so the backdrop matches the system
/// keyboard's blur. We can't implement a *sticky* Ctrl modifier
/// (the alphanumeric soft keys go straight to the WKWebView, not
/// through us), so the common Ctrl chords are exposed as direct keys
/// (^C/^D/^Z/^L/^R) alongside the symbols a shell needs most.
///
/// Bytes emitted match the standard xterm sequences so the agent on the
/// other end of the PTY sees the same input it would from a real
/// terminal (Esc 0x1B, Tab 0x09, Return 0x0D, arrows ESC[A..D, and the
/// C0 control codes for the Ctrl chords).
final class TerminalAccessoryBar: UIInputView {
    /// Called when the user taps a key. Bytes are routed through the
    /// same coordinator callback as keyboard input — keeps the harness
    /// path identical for both sources.
    var onSend: ((Data) -> Void)?

    private let barHeight: CGFloat = 48

    /// A single key: what it shows and what it sends.
    private struct Key {
        let label: String
        let bytes: [UInt8]
        /// Slightly wider cap for the multi-glyph labels so they don't
        /// look cramped next to the single-character symbol keys.
        var wide: Bool = false
    }

    // Ordered the way a thumb reaches for them: navigation/control
    // first, then the shell symbols. The row scrolls, so the list can
    // be generous without crowding.
    private static let keys: [Key] = [
        Key(label: "esc", bytes: [0x1B], wide: true),
        Key(label: "tab", bytes: [0x09], wide: true),
        Key(label: "↑", bytes: [0x1B, 0x5B, 0x41]),
        Key(label: "↓", bytes: [0x1B, 0x5B, 0x42]),
        Key(label: "←", bytes: [0x1B, 0x5B, 0x44]),
        Key(label: "→", bytes: [0x1B, 0x5B, 0x43]),
        Key(label: "^C", bytes: [0x03]),
        Key(label: "^D", bytes: [0x04]),
        Key(label: "^Z", bytes: [0x1A]),
        Key(label: "^L", bytes: [0x0C]),
        Key(label: "^R", bytes: [0x12]),
        Key(label: "|", bytes: [0x7C]),
        Key(label: "/", bytes: [0x2F]),
        Key(label: "\\", bytes: [0x5C]),
        Key(label: "~", bytes: [0x7E]),
        Key(label: "-", bytes: [0x2D]),
    ]

    private let scroll = UIScrollView()
    private let row = UIStackView()

    init() {
        super.init(
            frame: CGRect(x: 0, y: 0, width: 320, height: 48),
            inputViewStyle: .keyboard
        )
        autoresizingMask = .flexibleWidth
        allowsSelfSizing = true
        buildKeys()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Pin the bar height so UIKit lays the inputAccessoryView out at a
    // comfortable touch size regardless of the keys' intrinsic sizes.
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: barHeight)
    }

    private func buildKeys() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        addSubview(scroll)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 7
        scroll.addSubview(row)

        for key in Self.keys {
            row.addArrangedSubview(makeButton(for: key))
        }

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func makeButton(for key: Key) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = key.label
        config.cornerStyle = .medium
        config.baseForegroundColor = .label
        config.background.backgroundColor = UIColor.label.withAlphaComponent(0.10)
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6, leading: key.wide ? 14 : 11,
            bottom: 6, trailing: key.wide ? 14 : 11
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
            return out
        }

        let bytes = key.bytes
        let action = UIAction { [weak self] _ in
            self?.onSend?(Data(bytes))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        let button = UIButton(configuration: config, primaryAction: action)
        button.accessibilityLabel = key.label
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: key.wide ? 44 : 38).isActive = true
        return button
    }
}
