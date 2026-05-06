import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let systemHotCornerReader = SystemHotCornerReader()
    private lazy var screenshotRunner = ScreenshotRunner(settings: settings)
    private lazy var clipboardHistoryStore = ClipboardHistoryStore(settings: settings)
    private lazy var clipboardWindowController = ClipboardWindowController(
        settings: settings,
        historyStore: clipboardHistoryStore
    )
    private lazy var actionRunner = HotCornerActionRunner(
        screenshotRunner: screenshotRunner,
        clipboardWindowController: clipboardWindowController
    )
    private lazy var settingsWindowController = SettingsWindowController(
        settings: settings,
        systemHotCornerReader: systemHotCornerReader
    )
    private var monitor: CornerMonitor?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        clipboardHistoryStore.start()

        monitor = CornerMonitor(
            settings: settings,
            systemHotCornerReader: systemHotCornerReader,
            runner: actionRunner
        )
        monitor?.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemButton()
        settingsWindowController.onSettingsChanged = { [weak self] in
            self?.rebuildMenu()
        }
        settingsWindowController.onLanguageChanged = { [weak self] in
            self?.clipboardWindowController.applyLanguage()
            self?.rebuildMenu()
        }
        settingsWindowController.onClipboardPersistenceChanged = { [weak self] isEnabled in
            self?.clipboardHistoryStore.setPersistenceEnabled(isEnabled)
        }
        rebuildMenu()

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindowController.showSettings()
            }
        }
    }

    private func configureStatusItemButton() {
        statusItem?.isVisible = true

        guard let button = statusItem?.button else {
            return
        }

        let image = menuBarIconImage()

        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imagePosition = image == nil ? .noImage : .imageOnly
        button.title = image == nil ? "CS" : ""
        button.toolTip = "CornerShot"
    }

    private func menuBarIconImage() -> NSImage? {
        if let url = Bundle.main.url(
            forResource: "MenuBarIconTemplate",
            withExtension: "png"
        ), let image = NSImage(contentsOf: url) {
            return image
        }

        return NSImage(
            systemSymbolName: "cursorarrow",
            accessibilityDescription: "CornerShot"
        ) ?? NSImage(
            systemSymbolName: "bolt.circle",
            accessibilityDescription: "CornerShot"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardHistoryStore.flush()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let language = settings.language

        let enabledItem = NSMenuItem(
            title: settings.isEnabled
                ? text(language, korean: "켜짐", english: "Enabled")
                : text(language, korean: "꺼짐", english: "Disabled"),
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let settingsItem = NSMenuItem(
            title: text(language, korean: "핫코너 설정...", english: "Hot Corner Settings..."),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let openScreenshotFolderItem = NSMenuItem(
            title: text(language, korean: "스크린샷 폴더 열기", english: "Open Screenshot Folder"),
            action: #selector(openScreenshotFolder),
            keyEquivalent: ""
        )
        openScreenshotFolderItem.target = self
        menu.addItem(openScreenshotFolderItem)

        let clearClipboardDataItem = NSMenuItem(
            title: text(language, korean: "클립보드 모두삭제", english: "Clear Clipboard"),
            action: #selector(confirmClearClipboardData),
            keyEquivalent: ""
        )
        clearClipboardDataItem.target = self
        clearClipboardDataItem.isEnabled = clipboardHistoryStore.items.contains { !$0.isPinned }
        menu.addItem(clearClipboardDataItem)

        menu.addItem(.separator())

        let languageMenu = NSMenu()
        languageMenu.autoenablesItems = false
        for appLanguage in AppLanguage.allCases {
            let item = NSMenuItem(
                title: appLanguage.title,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = appLanguage.rawValue
            item.state = settings.language == appLanguage ? .on : .off
            languageMenu.addItem(item)
        }

        let languageItem = NSMenuItem(
            title: text(language, korean: "언어", english: "Language"),
            action: nil,
            keyEquivalent: ""
        )
        menu.setSubmenu(languageMenu, for: languageItem)
        menu.addItem(languageItem)

        menu.addItem(.separator())

        let summaryMenu = NSMenu()
        summaryMenu.autoenablesItems = false
        for corner in HotCorner.allCases {
            let action = settings.action(for: corner)
            let systemState = systemHotCornerReader.state(for: corner)
            let suffix = systemState.blocksPlainMouseTrigger
                ? text(language, korean: " (macOS 충돌)", english: " (macOS conflict)")
                : ""
            let item = NSMenuItem(
                title: "\(corner.title(language: language)): \(action.title(language: language))\(suffix)",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            summaryMenu.addItem(item)
        }

        let summaryItem = NSMenuItem(
            title: text(language, korean: "설정된 모서리", english: "Configured Corners"),
            action: nil,
            keyEquivalent: ""
        )
        menu.setSubmenu(summaryMenu, for: summaryItem)
        menu.addItem(summaryItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: text(language, korean: "CornerShot 종료", english: "Quit CornerShot"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsWindowController.showSettings()
        rebuildMenu()
    }

    @objc private func openScreenshotFolder() {
        let folderURL = settings.screenshotDirectoryURL
        if !NSWorkspace.shared.open(folderURL) {
            showOpenScreenshotFolderFailure(folderURL: folderURL)
        }
    }

    @objc private func confirmClearClipboardData() {
        let unpinnedCount = clipboardHistoryStore.items.filter { !$0.isPinned }.count
        guard unpinnedCount > 0 else {
            rebuildMenu()
            return
        }

        let language = settings.language
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text(
            language,
            korean: "클립보드 항목을 삭제할까요?",
            english: "Clear clipboard items?"
        )
        alert.informativeText = text(
            language,
            korean: "핀으로 고정하지 않은 클립보드 항목 \(unpinnedCount)개와 해당 OCR 데이터가 모두 삭제됩니다. 고정된 항목은 유지됩니다.",
            english: "\(unpinnedCount) unpinned clipboard item(s) and their OCR data will be deleted. Pinned items will be kept."
        )
        alert.icon = destructiveAlertIcon()
        let deleteButton = alert.addButton(withTitle: text(language, korean: "삭제", english: "Clear"))
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: text(language, korean: "취소", english: "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        clipboardHistoryStore.clear()
        rebuildMenu()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }

        settings.language = language
        clipboardWindowController.applyLanguage()
        settingsWindowController.applyLanguage()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showOpenScreenshotFolderFailure(folderURL: URL) {
        let language = settings.language
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text(
            language,
            korean: "스크린샷 폴더를 열 수 없습니다.",
            english: "Could not open the screenshot folder."
        )
        alert.informativeText = folderURL.path
        alert.addButton(withTitle: text(language, korean: "확인", english: "OK"))
        alert.runModal()
    }

    private func destructiveAlertIcon() -> NSImage {
        let size = NSSize(width: 72, height: 72)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()

        if let symbol = NSImage(
            systemSymbolName: "trash.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 32, weight: .bold)) {
            NSColor.white.set()
            symbol.draw(
                in: NSRect(x: 20, y: 18, width: 32, height: 34),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
