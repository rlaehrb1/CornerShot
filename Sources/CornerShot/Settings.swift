import Foundation

final class Settings {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let cornerActionPrefix = "cornerAction."
        static let language = "language"
        static let keepClipboardHistoryAfterQuit = "keepClipboardHistoryAfterQuit"
        static let screenshotDirectoryPath = "screenshotDirectoryPath"
        static let isImageOCREnabled = "isImageOCREnabled"
        static let legacyCorner = "corner"
        static let legacyAction = "action"
        static let legacyCaptureMode = "captureMode"
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Key.isEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.isEnabled) }
    }

    var keepClipboardHistoryAfterQuit: Bool {
        get { UserDefaults.standard.object(forKey: Key.keepClipboardHistoryAfterQuit) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.keepClipboardHistoryAfterQuit) }
    }

    var isImageOCREnabled: Bool {
        get { UserDefaults.standard.object(forKey: Key.isImageOCREnabled) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Key.isImageOCREnabled) }
    }

    var language: AppLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Key.language),
               let language = AppLanguage(rawValue: rawValue) {
                return language
            }

            let preferredLanguage = Locale.preferredLanguages.first ?? ""
            return preferredLanguage.hasPrefix("ko") ? .korean : .english
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.language) }
    }

    var screenshotDirectoryPath: String? {
        guard let path = UserDefaults.standard.string(forKey: Key.screenshotDirectoryPath),
              !path.isEmpty else {
            return nil
        }

        return path
    }

    var screenshotDirectoryURL: URL {
        if let path = screenshotDirectoryPath {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url
            }
        }

        return systemScreenshotDirectoryURL()
    }

    var screenshotDirectoryDisplayName: String {
        if screenshotDirectoryPath == nil {
            return text(
                language,
                korean: "macOS 기본값: \(abbreviatedPath(screenshotDirectoryURL.path))",
                english: "macOS default: \(abbreviatedPath(screenshotDirectoryURL.path))"
            )
        }

        return abbreviatedPath(screenshotDirectoryURL.path)
    }

    func setScreenshotDirectory(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Key.screenshotDirectoryPath)
    }

    func clearScreenshotDirectory() {
        UserDefaults.standard.removeObject(forKey: Key.screenshotDirectoryPath)
    }

    func action(for corner: HotCorner) -> CornerAction {
        if let storedAction = storedAction(for: corner) {
            return storedAction
        }

        guard !hasAnyStoredCornerAction,
              let legacyCorner = legacyCorner(),
              legacyCorner == corner else {
            return .none
        }

        return legacyAction()
    }

    func setAction(_ action: CornerAction, for corner: HotCorner) {
        UserDefaults.standard.set(action.rawValue, forKey: key(for: corner))
    }

    private var hasAnyStoredCornerAction: Bool {
        HotCorner.allCases.contains { storedAction(for: $0) != nil }
    }

    private func storedAction(for corner: HotCorner) -> CornerAction? {
        guard let rawValue = UserDefaults.standard.string(forKey: key(for: corner)) else {
            return nil
        }

        return CornerAction(rawValue: rawValue)
    }

    private func key(for corner: HotCorner) -> String {
        Key.cornerActionPrefix + corner.rawValue
    }

    private func legacyCorner() -> HotCorner? {
        guard let rawValue = UserDefaults.standard.string(forKey: Key.legacyCorner) else {
            return .bottomRight
        }

        return HotCorner(rawValue: rawValue)
    }

    private func legacyAction() -> CornerAction {
        if let rawValue = UserDefaults.standard.string(forKey: Key.legacyAction),
           let action = CornerAction(rawValue: rawValue) {
            return action
        }

        if let rawValue = UserDefaults.standard.string(forKey: Key.legacyCaptureMode),
           let mode = CaptureMode(rawValue: rawValue) {
            return CornerAction.screenshotAction(for: mode)
        }

        return .screenshotSelection
    }

    private func systemScreenshotDirectoryURL() -> URL {
        if let configuredPath = UserDefaults.standard
            .persistentDomain(forName: "com.apple.screencapture")?["location"] as? String,
           !configuredPath.isEmpty {
            return URL(fileURLWithPath: (configuredPath as NSString).expandingTildeInPath)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }

    private func abbreviatedPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
