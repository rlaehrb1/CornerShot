import AppKit

enum CornerShotDesign {
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Font {
        static let title = NSFont.systemFont(ofSize: 22, weight: .semibold)
        static let subtitle = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let section = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let caption = NSFont.systemFont(ofSize: 11, weight: .regular)
        static let captionMedium = NSFont.systemFont(ofSize: 11, weight: .medium)
        static let badge = NSFont.systemFont(ofSize: 10, weight: .medium)
    }

    static var windowBackgroundColor: NSColor {
        NSColor.windowBackgroundColor
    }

    static var surfaceColor: NSColor {
        NSColor.controlBackgroundColor.withAlphaComponent(0.96)
    }

    static var elevatedSurfaceColor: NSColor {
        NSColor.textBackgroundColor.withAlphaComponent(0.98)
    }

    static var mutedSurfaceColor: NSColor {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.14)
    }

    static var hoverColor: NSColor {
        NSColor.controlAccentColor.withAlphaComponent(0.08)
    }

    static var borderColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.48)
    }

    static var strongBorderColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(0.68)
    }

    static func applyWindowBackground(to view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = windowBackgroundColor.cgColor
    }

    static func applySurfaceStyle(
        to view: NSView,
        radius: CGFloat = Radius.medium,
        fillColor: NSColor? = nil,
        borderColor: NSColor? = nil,
        borderWidth: CGFloat = 1
    ) {
        view.wantsLayer = true
        view.layer?.backgroundColor = (fillColor ?? surfaceColor).cgColor
        view.layer?.borderWidth = borderWidth
        view.layer?.borderColor = (borderColor ?? CornerShotDesign.borderColor).cgColor
        view.layer?.cornerRadius = radius
    }

    static func applyQuietButtonStyle(_ button: NSButton, controlSize: NSControl.ControlSize = .regular) {
        button.bezelStyle = .rounded
        button.controlSize = controlSize
        button.font = NSFont.systemFont(ofSize: controlSize == .small ? 11 : 12, weight: .medium)
    }

    static func applyPopupStyle(_ popup: NSPopUpButton) {
        popup.controlSize = .regular
        popup.font = Font.body
    }
}
