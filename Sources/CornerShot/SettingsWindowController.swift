import AppKit
import Foundation

final class SettingsWindowController: NSWindowController {
    private let settings: Settings
    private let systemHotCornerReader: SystemHotCornerReader
    var onSettingsChanged: (() -> Void)?
    var onLanguageChanged: (() -> Void)?
    var onClipboardPersistenceChanged: ((Bool) -> Void)?

    private var cornerPanels: [HotCorner: NSView] = [:]
    private var cornerLabels: [HotCorner: NSTextField] = [:]
    private var actionPopups: [HotCorner: NSPopUpButton] = [:]
    private var systemLabels: [HotCorner: NSTextField] = [:]
    private var statusLabels: [HotCorner: NSTextField] = [:]
    private var statusBadges: [HotCorner: NSTextField] = [:]
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let screenLabel = NSTextField(labelWithString: "")
    private let noteLabel = NSTextField(wrappingLabelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let screenshotDirectoryTitleLabel = NSTextField(labelWithString: "")
    private let screenshotDirectoryPathLabel = NSTextField(labelWithString: "")
    private lazy var keepHistoryCheckbox = NSButton(
        checkboxWithTitle: "",
        target: self,
        action: #selector(keepHistoryChanged)
    )
    private lazy var imageOCRCheckbox = NSButton(
        checkboxWithTitle: "",
        target: self,
        action: #selector(imageOCRChanged)
    )
    private lazy var chooseScreenshotDirectoryButton = NSButton(
        title: "",
        target: self,
        action: #selector(chooseScreenshotDirectory)
    )
    private lazy var resetScreenshotDirectoryButton = NSButton(
        title: "",
        target: self,
        action: #selector(resetScreenshotDirectory)
    )
    private lazy var refreshButton = NSButton(
        title: "",
        target: self,
        action: #selector(refreshButtonClicked)
    )
    private lazy var openSystemSettingsButton = NSButton(
        title: "",
        target: self,
        action: #selector(openSystemSettings)
    )
    private lazy var closeButton = NSButton(
        title: "",
        target: self,
        action: #selector(closeSettings)
    )

    init(settings: Settings, systemHotCornerReader: SystemHotCornerReader) {
        self.settings = settings
        self.systemHotCornerReader = systemHotCornerReader

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 630),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CornerShot"
        window.minSize = NSSize(width: 720, height: 610)

        super.init(window: window)

        buildContent()
        applyLanguage()
        refreshSystemHotCorners()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func showSettings() {
        refreshSystemHotCorners()

        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        CornerShotDesign.applyWindowBackground(to: contentView)

        titleLabel.font = CornerShotDesign.Font.title

        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = CornerShotDesign.Font.subtitle
        subtitleLabel.isSelectable = false

        languageLabel.font = CornerShotDesign.Font.captionMedium
        languageLabel.textColor = .secondaryLabelColor
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.title)
            languagePopup.lastItem?.representedObject = language.rawValue
        }

        let languageStack = NSStackView(views: [languageLabel, languagePopup])
        languageStack.orientation = .horizontal
        languageStack.spacing = CornerShotDesign.Spacing.small
        languageStack.alignment = .centerY
        CornerShotDesign.applyPopupStyle(languagePopup)

        let previewContainer = NSView()
        CornerShotDesign.applySurfaceStyle(
            to: previewContainer,
            radius: CornerShotDesign.Radius.large,
            fillColor: CornerShotDesign.surfaceColor,
            borderColor: CornerShotDesign.strongBorderColor
        )

        let screenBox = NSView()
        CornerShotDesign.applySurfaceStyle(
            to: screenBox,
            radius: CornerShotDesign.Radius.medium,
            fillColor: CornerShotDesign.elevatedSurfaceColor,
            borderColor: CornerShotDesign.borderColor
        )

        screenLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        screenLabel.textColor = .secondaryLabelColor
        screenLabel.alignment = .center

        previewContainer.addSubview(screenBox)
        screenBox.addSubview(screenLabel)
        screenBox.translatesAutoresizingMaskIntoConstraints = false
        screenLabel.translatesAutoresizingMaskIntoConstraints = false

        let topLeftPanel = makeCornerPanel(for: .topLeft)
        let topRightPanel = makeCornerPanel(for: .topRight)
        let bottomLeftPanel = makeCornerPanel(for: .bottomLeft)
        let bottomRightPanel = makeCornerPanel(for: .bottomRight)

        for panel in [topLeftPanel, topRightPanel, bottomLeftPanel, bottomRightPanel] {
            previewContainer.addSubview(panel)
            panel.translatesAutoresizingMaskIntoConstraints = false
        }

        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = CornerShotDesign.Font.caption
        noteLabel.isSelectable = false
        keepHistoryCheckbox.state = settings.keepClipboardHistoryAfterQuit ? .on : .off
        imageOCRCheckbox.state = settings.isImageOCREnabled ? .on : .off
        screenshotDirectoryTitleLabel.font = CornerShotDesign.Font.captionMedium
        screenshotDirectoryTitleLabel.textColor = .secondaryLabelColor
        screenshotDirectoryPathLabel.font = CornerShotDesign.Font.body
        screenshotDirectoryPathLabel.lineBreakMode = .byTruncatingMiddle
        screenshotDirectoryPathLabel.usesSingleLineMode = true
        for button in [
            chooseScreenshotDirectoryButton,
            resetScreenshotDirectoryButton,
            refreshButton,
            openSystemSettingsButton,
            closeButton
        ] {
            CornerShotDesign.applyQuietButtonStyle(button)
        }

        let screenshotDirectoryInfoStack = NSStackView(views: [
            screenshotDirectoryTitleLabel,
            screenshotDirectoryPathLabel
        ])
        screenshotDirectoryInfoStack.orientation = .vertical
        screenshotDirectoryInfoStack.spacing = CornerShotDesign.Spacing.xSmall
        screenshotDirectoryInfoStack.alignment = .leading

        let screenshotDirectoryButtonStack = NSStackView(views: [
            chooseScreenshotDirectoryButton,
            resetScreenshotDirectoryButton
        ])
        screenshotDirectoryButtonStack.orientation = .horizontal
        screenshotDirectoryButtonStack.spacing = CornerShotDesign.Spacing.small
        screenshotDirectoryButtonStack.alignment = .centerY

        let screenshotDirectoryStack = NSStackView(views: [
            screenshotDirectoryInfoStack,
            screenshotDirectoryButtonStack
        ])
        screenshotDirectoryStack.orientation = .horizontal
        screenshotDirectoryStack.spacing = CornerShotDesign.Spacing.medium
        screenshotDirectoryStack.alignment = .centerY
        screenshotDirectoryStack.distribution = .fill

        let buttonStack = NSStackView(views: [
            refreshButton,
            openSystemSettingsButton,
            closeButton
        ])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = CornerShotDesign.Spacing.small
        buttonStack.alignment = .centerY

        for view in [
            titleLabel,
            languageStack,
            subtitleLabel,
            previewContainer,
            screenshotDirectoryStack,
            keepHistoryCheckbox,
            imageOCRCheckbox,
            noteLabel,
            buttonStack
        ] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: languageStack.leadingAnchor, constant: -18),

            languageStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            languageStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            previewContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            previewContainer.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            previewContainer.heightAnchor.constraint(equalToConstant: 304),

            screenBox.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            screenBox.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            screenBox.widthAnchor.constraint(equalToConstant: 184),
            screenBox.heightAnchor.constraint(equalToConstant: 88),

            screenLabel.centerXAnchor.constraint(equalTo: screenBox.centerXAnchor),
            screenLabel.centerYAnchor.constraint(equalTo: screenBox.centerYAnchor),

            topLeftPanel.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 18),
            topLeftPanel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 18),
            topLeftPanel.widthAnchor.constraint(equalToConstant: 236),
            topLeftPanel.heightAnchor.constraint(equalToConstant: 104),

            topRightPanel.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 18),
            topRightPanel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -18),
            topRightPanel.widthAnchor.constraint(equalToConstant: 236),
            topRightPanel.heightAnchor.constraint(equalToConstant: 104),

            bottomLeftPanel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -18),
            bottomLeftPanel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 18),
            bottomLeftPanel.widthAnchor.constraint(equalToConstant: 236),
            bottomLeftPanel.heightAnchor.constraint(equalToConstant: 104),

            bottomRightPanel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -18),
            bottomRightPanel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -18),
            bottomRightPanel.widthAnchor.constraint(equalToConstant: 236),
            bottomRightPanel.heightAnchor.constraint(equalToConstant: 104),

            screenshotDirectoryStack.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 14),
            screenshotDirectoryStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            screenshotDirectoryStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            screenshotDirectoryPathLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),

            keepHistoryCheckbox.topAnchor.constraint(equalTo: screenshotDirectoryStack.bottomAnchor, constant: 14),
            keepHistoryCheckbox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            keepHistoryCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -16),

            imageOCRCheckbox.topAnchor.constraint(equalTo: keepHistoryCheckbox.bottomAnchor, constant: 6),
            imageOCRCheckbox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            imageOCRCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -16),

            noteLabel.topAnchor.constraint(equalTo: imageOCRCheckbox.bottomAnchor, constant: 4),
            noteLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            noteLabel.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -18),

            buttonStack.centerYAnchor.constraint(equalTo: noteLabel.centerYAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            buttonStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func makeCornerPanel(for corner: HotCorner) -> NSView {
        let container = NSView()
        CornerShotDesign.applySurfaceStyle(
            to: container,
            radius: CornerShotDesign.Radius.medium,
            fillColor: CornerShotDesign.elevatedSurfaceColor,
            borderColor: CornerShotDesign.borderColor
        )

        let cornerLabel = NSTextField(labelWithString: corner.title(language: settings.language))
        cornerLabel.font = CornerShotDesign.Font.section
        cornerLabel.lineBreakMode = .byTruncatingTail
        cornerLabel.usesSingleLineMode = true

        let statusBadge = NSTextField(labelWithString: "")
        statusBadge.font = CornerShotDesign.Font.badge
        statusBadge.alignment = .center
        statusBadge.isSelectable = false
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = CornerShotDesign.Radius.small
        statusBadge.layer?.masksToBounds = true

        let headerSpacer = NSView()
        let headerStack = NSStackView(views: [cornerLabel, headerSpacer, statusBadge])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8

        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(actionChanged(_:))
        popup.identifier = NSUserInterfaceItemIdentifier(corner.rawValue)
        CornerShotDesign.applyPopupStyle(popup)
        configureActionPopup(popup, selectedAction: settings.action(for: corner))

        let systemLabel = singleLineLabel("")
        systemLabel.font = CornerShotDesign.Font.captionMedium

        let statusLabel = singleLineLabel("")
        statusLabel.font = CornerShotDesign.Font.caption
        statusLabel.textColor = .secondaryLabelColor

        cornerPanels[corner] = container
        cornerLabels[corner] = cornerLabel
        actionPopups[corner] = popup
        systemLabels[corner] = systemLabel
        statusLabels[corner] = statusLabel
        statusBadges[corner] = statusBadge

        let stack = NSStackView(views: [
            headerStack,
            popup,
            systemLabel,
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -9),
            popup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
            statusBadge.heightAnchor.constraint(equalToConstant: 18)
        ])

        return container
    }

    private func singleLineLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        return label
    }

    private func wrappingLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.isSelectable = false
        return label
    }

    func applyLanguage() {
        let language = settings.language
        window?.title = text(language, korean: "CornerShot 핫코너", english: "CornerShot Hot Corners")
        titleLabel.stringValue = text(language, korean: "CornerShot 핫코너", english: "CornerShot Hot Corners")
        subtitleLabel.stringValue = text(
            language,
            korean: "각 모서리에 실행할 동작을 고르세요. macOS 핫코너와 충돌하면 바로 표시됩니다.",
            english: "Choose an action for each corner. macOS hot-corner conflicts are shown here."
        )
        screenLabel.stringValue = text(language, korean: "화면", english: "Screen")
        noteLabel.stringValue = text(
            language,
            korean: "클립보드와 OCR 데이터는 이 Mac에만 저장됩니다.",
            english: "Clipboard and OCR data stay on this Mac."
        )
        languageLabel.stringValue = text(language, korean: "언어", english: "Language")
        languagePopup.selectItem(withTitle: language.title)
        screenshotDirectoryTitleLabel.stringValue = text(
            language,
            korean: "스크린샷 저장 위치",
            english: "Screenshot Save Location"
        )
        chooseScreenshotDirectoryButton.title = text(
            language,
            korean: "폴더 선택...",
            english: "Choose Folder..."
        )
        resetScreenshotDirectoryButton.title = text(
            language,
            korean: "기본값",
            english: "Default"
        )
        keepHistoryCheckbox.title = text(
            language,
            korean: "앱 종료 후에도 클립보드 히스토리 저장",
            english: "Keep clipboard history after quit"
        )
        keepHistoryCheckbox.state = settings.keepClipboardHistoryAfterQuit ? .on : .off
        imageOCRCheckbox.title = text(
            language,
            korean: "이미지 OCR 검색 사용",
            english: "Use image OCR search"
        )
        imageOCRCheckbox.state = settings.isImageOCREnabled ? .on : .off
        refreshButton.title = text(language, korean: "macOS 새로고침", english: "Refresh macOS")
        openSystemSettingsButton.title = text(language, korean: "macOS 핫코너 열기", english: "Open macOS Hot Corners")
        closeButton.title = text(language, korean: "완료", english: "Done")

        for corner in HotCorner.allCases {
            cornerLabels[corner]?.stringValue = corner.title(language: language)
            if let popup = actionPopups[corner] {
                configureActionPopup(popup, selectedAction: settings.action(for: corner))
            }
        }

        refreshScreenshotDirectoryLabel()
        refreshSystemHotCorners()
    }

    private func configureActionPopup(_ popup: NSPopUpButton, selectedAction: CornerAction) {
        popup.removeAllItems()
        for action in CornerAction.allCases {
            popup.addItem(withTitle: action.title(language: settings.language))
            popup.lastItem?.representedObject = action.rawValue
        }
        popup.selectItem(withTitle: selectedAction.title(language: settings.language))
    }

    private func refreshSystemHotCorners() {
        let language = settings.language
        for corner in HotCorner.allCases {
            let state = systemHotCornerReader.state(for: corner)
            let action = settings.action(for: corner)

            actionPopups[corner]?.selectItem(withTitle: action.title(language: language))
            systemLabels[corner]?.stringValue = state.title(language: language)
            let primaryColor: NSColor = state.blocksPlainMouseTrigger
                ? .systemRed
                : .secondaryLabelColor
            systemLabels[corner]?.textColor = primaryColor
            statusLabels[corner]?.stringValue = compactStatus(for: state, language: language)
            statusLabels[corner]?.textColor = primaryColor
            updateStatusBadge(for: corner, state: state, language: language)
            updatePanelAppearance(for: corner, state: state)
        }
    }

    private func compactStatus(for state: SystemHotCornerState, language: AppLanguage) -> String {
        if state.blocksPlainMouseTrigger {
            return text(language, korean: "macOS 설정을 비우면 사용 가능", english: "Clear macOS setting to use")
        }

        if state.isAssigned {
            return text(language, korean: "수정키 없이 CornerShot 사용 가능", english: "CornerShot works without the modifier")
        }

        return text(language, korean: "CornerShot에서 바로 사용 가능", english: "Available for CornerShot")
    }

    private func updateStatusBadge(
        for corner: HotCorner,
        state: SystemHotCornerState,
        language: AppLanguage
    ) {
        guard let badge = statusBadges[corner] else {
            return
        }

        if state.blocksPlainMouseTrigger {
            badge.stringValue = text(language, korean: "충돌", english: "Conflict")
            badge.textColor = .systemRed
            badge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
            badge.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.16).cgColor
        } else if state.isAssigned {
            badge.stringValue = text(language, korean: "수정키", english: "With Key")
            badge.textColor = .systemOrange
            badge.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
            badge.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.16).cgColor
        } else {
            badge.stringValue = text(language, korean: "가능", english: "Available")
            badge.textColor = .secondaryLabelColor
            badge.layer?.backgroundColor = CornerShotDesign.mutedSurfaceColor.cgColor
            badge.layer?.borderColor = CornerShotDesign.borderColor.cgColor
        }
        badge.layer?.borderWidth = 1
    }

    private func updatePanelAppearance(for corner: HotCorner, state: SystemHotCornerState) {
        guard let panel = cornerPanels[corner] else {
            return
        }

        if state.blocksPlainMouseTrigger {
            panel.layer?.borderWidth = 1.5
            panel.layer?.borderColor = NSColor.systemRed.cgColor
            panel.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.055).cgColor
        } else {
            panel.layer?.borderWidth = 1
            panel.layer?.borderColor = CornerShotDesign.borderColor.cgColor
            panel.layer?.backgroundColor = CornerShotDesign.elevatedSurfaceColor.cgColor
        }
    }

    @objc private func actionChanged(_ sender: NSPopUpButton) {
        guard let identifier = sender.identifier?.rawValue,
              let corner = HotCorner(rawValue: identifier),
              let rawValue = sender.selectedItem?.representedObject as? String,
              let action = CornerAction(rawValue: rawValue) else {
            return
        }

        settings.setAction(action, for: corner)
        refreshSystemHotCorners()
        onSettingsChanged?()
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }

        settings.language = language
        applyLanguage()
        onLanguageChanged?()
    }

    @objc private func keepHistoryChanged(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        settings.keepClipboardHistoryAfterQuit = isEnabled
        onClipboardPersistenceChanged?(isEnabled)
    }

    @objc private func imageOCRChanged(_ sender: NSButton) {
        settings.isImageOCREnabled = sender.state == .on
    }

    @objc private func chooseScreenshotDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.screenshotDirectoryURL
        panel.prompt = text(settings.language, korean: "선택", english: "Choose")
        panel.message = text(
            settings.language,
            korean: "CornerShot 스크린샷을 저장할 폴더를 선택하세요.",
            english: "Choose where CornerShot screenshots should be saved."
        )

        guard let window else {
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                settings.setScreenshotDirectory(url)
                refreshScreenshotDirectoryLabel()
            }
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            self?.settings.setScreenshotDirectory(url)
            self?.refreshScreenshotDirectoryLabel()
        }
    }

    @objc private func resetScreenshotDirectory() {
        settings.clearScreenshotDirectory()
        refreshScreenshotDirectoryLabel()
    }

    @objc private func refreshButtonClicked() {
        refreshSystemHotCorners()
        onSettingsChanged?()
    }

    @objc private func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func closeSettings() {
        window?.close()
    }

    private func refreshScreenshotDirectoryLabel() {
        screenshotDirectoryPathLabel.stringValue = settings.screenshotDirectoryDisplayName
        screenshotDirectoryPathLabel.toolTip = settings.screenshotDirectoryURL.path
        resetScreenshotDirectoryButton.isEnabled = settings.screenshotDirectoryPath != nil
    }
}
