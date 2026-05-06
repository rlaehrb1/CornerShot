import AppKit
import Foundation

enum ClipboardHistoryKind: String, Codable {
    case text
    case image
    case files
    case unsupported
}

struct ClipboardHistoryItem: Codable, Identifiable {
    let id: UUID
    var createdAt: Date
    let kind: ClipboardHistoryKind
    let previewTitle: String
    let previewText: String
    let textValue: String?
    let imageData: Data?
    let fileURLs: [URL]
    let unsupportedTypes: [String]
    let fingerprint: String
    var isPinned: Bool
    var ocrText: String?
    var isOCRProcessed: Bool
    var searchText: String

    init(
        id: UUID,
        createdAt: Date,
        kind: ClipboardHistoryKind,
        previewTitle: String,
        previewText: String,
        textValue: String?,
        imageData: Data?,
        fileURLs: [URL],
        unsupportedTypes: [String],
        fingerprint: String,
        isPinned: Bool = false,
        ocrText: String? = nil,
        isOCRProcessed: Bool = false,
        searchText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.previewTitle = previewTitle
        self.previewText = previewText
        self.textValue = textValue
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.unsupportedTypes = unsupportedTypes
        self.fingerprint = fingerprint
        self.isPinned = isPinned
        self.ocrText = ocrText
        self.isOCRProcessed = isOCRProcessed
        self.searchText = searchText ?? Self.makeSearchText(
            previewTitle: previewTitle,
            previewText: previewText,
            textValue: textValue,
            ocrText: ocrText,
            fileURLs: fileURLs,
            unsupportedTypes: unsupportedTypes
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case kind
        case previewTitle
        case previewText
        case textValue
        case imageData
        case fileURLs
        case unsupportedTypes
        case fingerprint
        case isPinned
        case ocrText
        case isOCRProcessed
        case searchText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        kind = try container.decode(ClipboardHistoryKind.self, forKey: .kind)
        previewTitle = try container.decode(String.self, forKey: .previewTitle)
        previewText = try container.decode(String.self, forKey: .previewText)
        textValue = try container.decodeIfPresent(String.self, forKey: .textValue)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        fileURLs = try container.decode([URL].self, forKey: .fileURLs)
        unsupportedTypes = try container.decode([String].self, forKey: .unsupportedTypes)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
        isOCRProcessed = try container.decodeIfPresent(Bool.self, forKey: .isOCRProcessed) ?? false
        let decodedSearchText = try container.decodeIfPresent(String.self, forKey: .searchText)
        searchText = decodedSearchText ?? Self.makeSearchText(
            previewTitle: previewTitle,
            previewText: previewText,
            textValue: textValue,
            ocrText: ocrText,
            fileURLs: fileURLs,
            unsupportedTypes: unsupportedTypes
        )
        if decodedSearchText == nil || decodedSearchText?.isEmpty == true {
            searchText = Self.makeSearchText(
                previewTitle: previewTitle,
                previewText: previewText,
                textValue: textValue,
                ocrText: ocrText,
                fileURLs: fileURLs,
                unsupportedTypes: unsupportedTypes
            )
        }
    }

    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = Self.normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return searchText.contains(normalizedQuery)
    }

    mutating func setOCRText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        ocrText = trimmedText.isEmpty ? nil : trimmedText
        isOCRProcessed = true
        refreshSearchText()
    }

    mutating func refreshSearchText() {
        searchText = Self.makeSearchText(
            previewTitle: previewTitle,
            previewText: previewText,
            textValue: textValue,
            ocrText: ocrText,
            fileURLs: fileURLs,
            unsupportedTypes: unsupportedTypes
        )
    }

    static func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeSearchText(
        previewTitle: String,
        previewText: String,
        textValue: String?,
        ocrText: String?,
        fileURLs: [URL],
        unsupportedTypes: [String]
    ) -> String {
        let text = [
            previewTitle,
            previewText,
            textValue,
            ocrText,
            fileURLs.map(\.lastPathComponent).joined(separator: " "),
            unsupportedTypes.joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        return normalizedSearchText(text)
    }
}

final class ClipboardHistoryStore {
    static let maxItems = 50

    private let settings: Settings
    private let ocrReader = OCRReader()
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var isPaused = false

    private(set) var items: [ClipboardHistoryItem] = [] {
        didSet {
            onChange?(items)
        }
    }

    var onChange: (([ClipboardHistoryItem]) -> Void)?

    init(settings: Settings) {
        self.settings = settings
        deleteLegacyImageDragCache()
        if settings.keepClipboardHistoryAfterQuit {
            load()
        }
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount

        timer?.invalidate()
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }

    func setPaused(_ isPaused: Bool) {
        self.isPaused = isPaused
    }

    func refresh() {
        lastChangeCount = NSPasteboard.general.changeCount
        ingestCurrentPasteboard()
    }

    func clear() {
        items.removeAll { !$0.isPinned }
        saveIfNeeded()
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveIfNeeded()
    }

    func togglePinned(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].isPinned.toggle()
        trimToLimit()
        saveIfNeeded()
    }

    func flush() {
        saveIfNeeded()
    }

    func setPersistenceEnabled(_ isEnabled: Bool) {
        if isEnabled {
            saveIfNeeded()
        } else {
            deleteStoredHistory()
        }
    }

    private func pollPasteboard() {
        guard !isPaused else {
            return
        }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount
        ingestCurrentPasteboard()
    }

    private func ingestCurrentPasteboard() {
        guard let item = makeItem(from: NSPasteboard.general) else {
            return
        }

        var insertedItem: ClipboardHistoryItem?
        if let duplicateIndex = items.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
            var duplicate = items.remove(at: duplicateIndex)
            duplicate.createdAt = Date()
            items.insert(duplicate, at: 0)
        } else {
            items.insert(item, at: 0)
            insertedItem = item
        }

        trimToLimit()
        saveIfNeeded()

        if let insertedItem {
            startOCRIfNeeded(for: insertedItem)
        }
    }

    private func makeItem(from pasteboard: NSPasteboard) -> ClipboardHistoryItem? {
        if let urls = fileURLs(from: pasteboard), !urls.isEmpty {
            return fileItem(urls: urls)
        }

        if let imageData = imageData(from: pasteboard),
           let image = NSImage(data: imageData),
           image.isValid {
            return imageItem(data: imageData, image: image)
        }

        if let textValue = textValue(from: pasteboard), !textValue.isEmpty {
            return textItem(textValue)
        }

        let types = pasteboard.types?.map(\.rawValue).sorted() ?? []
        guard !types.isEmpty else {
            return nil
        }

        return unsupportedItem(types: types)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            let fileURLs = urls.filter(\.isFileURL)
            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let data = pasteboard.data(forType: filenamesType),
              let filenames = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String],
              !filenames.isEmpty else {
            return nil
        }

        return filenames.map { URL(fileURLWithPath: $0) }
    }

    private func textValue(from pasteboard: NSPasteboard) -> String? {
        let textTypes: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("NSStringPboardType")
        ]

        for type in textTypes {
            if let value = pasteboard.string(forType: type), !value.isEmpty {
                return value
            }
        }

        if let rtfData = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ),
           !attributed.string.isEmpty {
            return attributed.string
        }

        if let html = pasteboard.string(forType: .html), !html.isEmpty {
            return html
        }

        return nil
    }

    private func imageData(from pasteboard: NSPasteboard) -> Data? {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif")
        ]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data),
               image.isValid {
                return image.tiffRepresentation ?? data
            }
        }

        guard let image = NSImage(pasteboard: pasteboard), image.isValid else {
            return nil
        }

        return image.tiffRepresentation
    }

    private func textItem(_ value: String) -> ClipboardHistoryItem {
        let preview = singleLine(value)
        return ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .text,
            previewTitle: preview.isEmpty ? "Text" : preview,
            previewText: value,
            textValue: value,
            imageData: nil,
            fileURLs: [],
            unsupportedTypes: [],
            fingerprint: "text:\(value)",
            isPinned: false
        )
    }

    private func imageItem(data: Data, image: NSImage) -> ClipboardHistoryItem {
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        return ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .image,
            previewTitle: "Image \(width) x \(height)",
            previewText: "\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))",
            textValue: nil,
            imageData: data,
            fileURLs: [],
            unsupportedTypes: [],
            fingerprint: "image:\(data.count):\(data.prefix(4096).base64EncodedString())",
            isPinned: false
        )
    }

    private func fileItem(urls: [URL]) -> ClipboardHistoryItem {
        let names = urls.map { $0.lastPathComponent.isEmpty ? $0.absoluteString : $0.lastPathComponent }
        let title = names.count == 1 ? names[0] : "\(names[0]) + \(names.count - 1)"
        return ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .files,
            previewTitle: title,
            previewText: names.joined(separator: "\n"),
            textValue: nil,
            imageData: nil,
            fileURLs: urls,
            unsupportedTypes: [],
            fingerprint: "files:\(urls.map(\.absoluteString).joined(separator: "\u{1f}"))",
            isPinned: false
        )
    }

    private func unsupportedItem(types: [String]) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            createdAt: Date(),
            kind: .unsupported,
            previewTitle: "Unsupported clipboard data",
            previewText: types.joined(separator: "\n"),
            textValue: nil,
            imageData: nil,
            fileURLs: [],
            unsupportedTypes: types,
            fingerprint: "unsupported:\(types.joined(separator: "\u{1f}"))",
            isPinned: false
        )
    }

    private func startOCRIfNeeded(for item: ClipboardHistoryItem) {
        guard settings.isImageOCREnabled,
              item.kind == .image,
              !item.isOCRProcessed,
              let imageData = item.imageData else {
            return
        }

        ocrReader.recognizeText(from: imageData) { [weak self] recognizedText in
            self?.completeOCR(text: recognizedText, for: item.id)
        }
    }

    private func completeOCR(text: String, for id: UUID) {
        guard settings.isImageOCREnabled,
              let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].setOCRText(text)
        saveIfNeeded()
    }

    private func singleLine(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= 15 {
            return collapsed
        }

        return String(collapsed.prefix(15)) + "..."
    }

    private func trimToLimit() {
        var unpinnedCount = 0
        items = items.filter { item in
            if item.isPinned {
                return true
            }

            unpinnedCount += 1
            return unpinnedCount <= Self.maxItems
        }
    }

    private func saveIfNeeded() {
        guard settings.keepClipboardHistoryAfterQuit else {
            return
        }

        do {
            let directory = storageDirectory()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL(), options: .atomic)
        } catch {
            // Clipboard history is a convenience cache; failing to save should not break the app.
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL())
            items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)
            for index in items.indices {
                items[index].refreshSearchText()
            }
            trimToLimit()
        } catch {
            items = []
        }
    }

    private func deleteStoredHistory() {
        try? FileManager.default.removeItem(at: storageURL())
    }

    private func deleteLegacyImageDragCache() {
        let baseURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let legacyDragDirectory = baseURL
            .appendingPathComponent("CornerShot", isDirectory: true)
            .appendingPathComponent("DragItems", isDirectory: true)

        try? FileManager.default.removeItem(at: legacyDragDirectory)
    }

    private func storageDirectory() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return baseURL
            .appendingPathComponent("CornerShot", isDirectory: true)
            .appendingPathComponent("clipboard-history", isDirectory: true)
    }

    private func storageURL() -> URL {
        storageDirectory().appendingPathComponent("history.json")
    }
}

final class ClipboardHistoryRowView: NSView, NSDraggingSource {
    static let rowHeight: CGFloat = 64

    private let item: ClipboardHistoryItem
    private let language: AppLanguage
    private let onDelete: (UUID) -> Void
    private let onTogglePinned: (UUID) -> Void
    private var mouseDownEvent: NSEvent?
    private var trackingArea: NSTrackingArea?
    private let dragHandleImageView = NSImageView()
    private let pinButton = NSButton()
    private let deleteButton = NSButton()
    private var activeImageDragWriters: [ImageDragPasteboardWriter] = []
    private var activeTemporaryDragURLs: [URL] = []

    init(
        item: ClipboardHistoryItem,
        language: AppLanguage,
        onDelete: @escaping (UUID) -> Void,
        onTogglePinned: @escaping (UUID) -> Void
    ) {
        self.item = item
        self.language = language
        self.onDelete = onDelete
        self.onTogglePinned = onTogglePinned
        super.init(frame: .zero)

        buildContent()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = CornerShotDesign.hoverColor.cgColor
        dragHandleImageView.contentTintColor = .secondaryLabelColor
        deleteButton.contentTintColor = .secondaryLabelColor
        pinButton.contentTintColor = item.isPinned ? .systemBlue : .secondaryLabelColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = CornerShotDesign.surfaceColor.cgColor
        dragHandleImageView.contentTintColor = .tertiaryLabelColor
        deleteButton.contentTintColor = .tertiaryLabelColor
        pinButton.contentTintColor = item.isPinned ? .systemBlue : .tertiaryLabelColor
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent,
              event.locationInWindow.distance(to: mouseDownEvent.locationInWindow) > 4 else {
            return
        }

        let draggingItems = pasteboardWriters().map { writer -> NSDraggingItem in
            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            draggingItem.setDraggingFrame(bounds, contents: draggingImage())
            return draggingItem
        }

        guard !draggingItems.isEmpty else {
            return
        }

        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
        self.mouseDownEvent = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        let temporaryURLs = activeTemporaryDragURLs
        activeTemporaryDragURLs.removeAll()
        activeImageDragWriters.removeAll()

        let cleanupDelay: TimeInterval = operation.isEmpty ? 0 : 120
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + cleanupDelay) {
            for url in temporaryURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func buildContent() {
        CornerShotDesign.applySurfaceStyle(
            to: self,
            radius: CornerShotDesign.Radius.medium,
            fillColor: CornerShotDesign.surfaceColor,
            borderColor: CornerShotDesign.borderColor
        )

        let previewContainer = NSView()
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = previewBackgroundColor().cgColor
        previewContainer.layer?.cornerRadius = item.kind == .image
            ? CornerShotDesign.Radius.small
            : CornerShotDesign.Radius.medium
        previewContainer.layer?.masksToBounds = true

        let iconView = NSImageView()
        iconView.image = icon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        previewContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let ocrBadge = makeOCRBadgeIfNeeded()
        if let ocrBadge {
            previewContainer.addSubview(ocrBadge)
            ocrBadge.translatesAutoresizingMaskIntoConstraints = false
        }

        let titleLabel = NSTextField(labelWithString: title())
        titleLabel.font = CornerShotDesign.Font.section
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        titleLabel.maximumNumberOfLines = 1
        titleLabel.toolTip = tooltipText()
        toolTip = tooltipText()

        let subtitleLabel = NSTextField(labelWithString: subtitle())
        subtitleLabel.font = CornerShotDesign.Font.caption
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.usesSingleLineMode = true
        subtitleLabel.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = CornerShotDesign.Spacing.xSmall
        textStack.alignment = .leading

        dragHandleImageView.image = NSImage(
            systemSymbolName: "line.3.horizontal",
            accessibilityDescription: "Drag"
        )
        dragHandleImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        dragHandleImageView.contentTintColor = .tertiaryLabelColor
        dragHandleImageView.imageScaling = .scaleProportionallyDown

        configureIconButton(
            pinButton,
            symbolName: item.isPinned ? "pin.fill" : "pin",
            tintColor: item.isPinned ? .systemBlue : .tertiaryLabelColor,
            tooltip: item.isPinned
                ? text(language, korean: "고정 해제", english: "Unpin")
                : text(language, korean: "항목 고정", english: "Pin")
        )
        pinButton.target = self
        pinButton.action = #selector(pinButtonClicked)

        configureIconButton(
            deleteButton,
            symbolName: "xmark",
            tintColor: .tertiaryLabelColor,
            tooltip: text(language, korean: "항목 삭제", english: "Delete")
        )
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonClicked)

        let actionStack = NSStackView(views: [pinButton, deleteButton, dragHandleImageView])
        actionStack.orientation = .horizontal
        actionStack.spacing = CornerShotDesign.Spacing.xSmall
        actionStack.alignment = .centerY

        for view in [previewContainer, textStack, actionStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        let previewSize: CGFloat = item.kind == .image ? 46 : 34
        let iconInset: CGFloat = item.kind == .image ? 0 : 6

        NSLayoutConstraint.activate([
            previewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            previewContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewContainer.widthAnchor.constraint(equalToConstant: previewSize),
            previewContainer.heightAnchor.constraint(equalToConstant: previewSize),

            iconView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: iconInset),
            iconView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: iconInset),
            iconView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -iconInset),
            iconView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -iconInset),

            textStack.leadingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: actionStack.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            actionStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            pinButton.widthAnchor.constraint(equalToConstant: 22),
            pinButton.heightAnchor.constraint(equalToConstant: 22),
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.heightAnchor.constraint(equalToConstant: 22),
            dragHandleImageView.widthAnchor.constraint(equalToConstant: 16),
            dragHandleImageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        if let ocrBadge {
            NSLayoutConstraint.activate([
                ocrBadge.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 3),
                ocrBadge.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -3),
                ocrBadge.widthAnchor.constraint(equalToConstant: 8),
                ocrBadge.heightAnchor.constraint(equalToConstant: 8)
            ])
        }
    }

    private func makeOCRBadgeIfNeeded() -> NSView? {
        guard item.kind == .image, item.isOCRProcessed else {
            return nil
        }

        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.systemBlue.cgColor
        badge.layer?.cornerRadius = 4
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
        badge.toolTip = text(language, korean: "OCR 검색 가능", english: "OCR searchable")
        return badge
    }

    private func previewBackgroundColor() -> NSColor {
        switch item.kind {
        case .text:
            return NSColor.systemBlue.withAlphaComponent(0.10)
        case .image:
            return NSColor.black.withAlphaComponent(0.06)
        case .files:
            return NSColor.systemPurple.withAlphaComponent(0.10)
        case .unsupported:
            return CornerShotDesign.mutedSurfaceColor
        }
    }

    private func configureIconButton(
        _ button: NSButton,
        symbolName: String,
        tintColor: NSColor,
        tooltip: String
    ) {
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.controlSize = .small
        button.contentTintColor = tintColor
        button.toolTip = tooltip
        button.setButtonType(.momentaryChange)
    }

    @objc private func pinButtonClicked() {
        onTogglePinned(item.id)
    }

    @objc private func deleteButtonClicked() {
        onDelete(item.id)
    }

    private func subtitle() -> String {
        let kindTitle: String
        switch item.kind {
        case .text:
            kindTitle = text(language, korean: "텍스트", english: "Text")
        case .image:
            let size = item.imageData.map {
                ByteCountFormatter.string(fromByteCount: Int64($0.count), countStyle: .file)
            } ?? ""
            let imageInfo = size.isEmpty ? "TIFF" : "TIFF · \(size)"
            kindTitle = imageInfo
        case .files:
            kindTitle = text(language, korean: "파일 · \(item.fileURLs.count)개", english: "File · \(item.fileURLs.count) item(s)")
        case .unsupported:
            kindTitle = text(language, korean: "지원하지 않는 형식", english: "Unsupported Type")
        }

        let time = DateFormatter.localizedString(
            from: item.createdAt,
            dateStyle: .none,
            timeStyle: .short
        )
        return "\(kindTitle) · \(time)"
    }

    private func title() -> String {
        switch item.kind {
        case .text:
            return textPreview(item.textValue ?? item.previewTitle)
        case .files:
            return item.previewTitle
        case .image:
            guard let data = item.imageData,
                  let image = NSImage(data: data) else {
                return text(language, korean: "이미지", english: "Image")
            }

            let width = Int(image.size.width.rounded())
            let height = Int(image.size.height.rounded())
            return text(language, korean: "이미지 \(width) x \(height)", english: "Image \(width) x \(height)")
        case .unsupported:
            return text(language, korean: "지원하지 않는 클립보드 데이터", english: "Unsupported clipboard data")
        }
    }

    private func textPreview(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.count > 28 else {
            return collapsed
        }

        return String(collapsed.prefix(28)) + "..."
    }

    private func tooltipText() -> String? {
        switch item.kind {
        case .text:
            return item.textValue
        default:
            return nil
        }
    }

    private func icon() -> NSImage? {
        switch item.kind {
        case .text:
            return NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Text")
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                return image
            }
            return NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
        case .files:
            if item.fileURLs.count == 1, let path = item.fileURLs.first?.path {
                return NSWorkspace.shared.icon(forFile: path)
            }
            return NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Files")
        case .unsupported:
            return NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: "Unsupported")
        }
    }

    private func pasteboardWriters() -> [NSPasteboardWriting] {
        switch item.kind {
        case .text:
            guard let text = item.textValue else {
                return []
            }
            return [text as NSString]
        case .image:
            guard let data = item.imageData else {
                return []
            }

            guard let writer = temporaryImageDragWriter(from: data) else {
                let pasteboardItem = NSPasteboardItem()
                pasteboardItem.setData(data, forType: .tiff)
                return [pasteboardItem]
            }

            activeImageDragWriters = [writer]
            activeTemporaryDragURLs = [writer.fileURL]
            return [writer]
        case .files:
            return item.fileURLs.map { $0 as NSURL }
        case .unsupported:
            return []
        }
    }

    private func temporaryImageDragWriter(from tiffData: Data) -> ImageDragPasteboardWriter? {
        let pngData = imagePNGData(from: tiffData) ?? tiffData
        let directory = Self.temporaryImageDragDirectory()

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            cleanupStaleTemporaryImageDragFiles(in: directory)

            let fileURL = directory.appendingPathComponent(imageFileName(fileExtension: "png"))
            try pngData.write(to: fileURL, options: .atomic)
            return ImageDragPasteboardWriter(
                fileURL: fileURL,
                pngData: pngData,
                tiffData: tiffData
            )
        } catch {
            return nil
        }
    }

    private func imagePNGData(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func imageFileName(fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "CornerShot Image \(formatter.string(from: item.createdAt)) \(item.id.uuidString.prefix(8)).\(fileExtension)"
    }

    private static func temporaryImageDragDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CornerShot", isDirectory: true)
            .appendingPathComponent("DragItems", isDirectory: true)
    }

    private func cleanupStaleTemporaryImageDragFiles(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let expirationDate = Date().addingTimeInterval(-10 * 60)
        for file in files {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modifiedAt = values?.contentModificationDate,
                  modifiedAt < expirationDate else {
                continue
            }

            try? FileManager.default.removeItem(at: file)
        }
    }

    private func draggingImage() -> NSImage {
        guard bounds.width > 0, bounds.height > 0,
              let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return NSImage(size: NSSize(width: 260, height: 52))
        }

        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    static func rowHeight(for _: ClipboardHistoryItem) -> CGFloat {
        rowHeight
    }
}

final class ImageDragPasteboardWriter: NSObject, NSPasteboardWriting {
    private static let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    private static let publicURLType = NSPasteboard.PasteboardType("public.url")
    private static let publicURLNameType = NSPasteboard.PasteboardType("public.url-name")

    let fileURL: URL
    private let pngData: Data
    private let tiffData: Data

    init(fileURL: URL, pngData: Data, tiffData: Data) {
        self.fileURL = fileURL
        self.pngData = pngData
        self.tiffData = tiffData
        super.init()
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [
            .fileURL,
            Self.filenamesType,
            Self.publicURLType,
            Self.publicURLNameType,
            .png,
            .tiff
        ]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL:
            return fileURL.absoluteString
        case Self.filenamesType:
            return [fileURL.path]
        case Self.publicURLType:
            return fileURL.absoluteString
        case Self.publicURLNameType:
            return fileURL.lastPathComponent
        case .png:
            return pngData
        case .tiff:
            return tiffData
        default:
            return nil
        }
    }
}

extension NSPoint {
    func distance(to other: NSPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

final class ClipboardWindowController: NSWindowController, NSSearchFieldDelegate {
    private enum Layout {
        static let edgeMargin: CGFloat = 10
        static let contentMargin: CGFloat = 12
        static let preferredContentWidth: CGFloat = 420
        static let baseContentHeight: CGFloat = 124
        static let minContentSize = NSSize(width: 380, height: 190)
        static let emptyListHeight: CGFloat = 104
        static let maxVisibleRows = 4
        static let rowSpacing: CGFloat = 6
        static let listVerticalInsets: CGFloat = 0
    }

    private let settings: Settings
    private let historyStore: ClipboardHistoryStore
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private let scrollView = NSScrollView()
    private let listStack = NSStackView()
    private var searchQuery = ""
    private lazy var refreshButton = NSButton(
        title: "",
        target: self,
        action: #selector(refresh)
    )
    private lazy var clearButton = NSButton(
        title: "",
        target: self,
        action: #selector(clearHistory)
    )
    private lazy var closeButton = NSButton(
        title: "",
        target: self,
        action: #selector(closeClipboardWindow)
    )

    init(settings: Settings, historyStore: ClipboardHistoryStore) {
        self.settings = settings
        self.historyStore = historyStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 240),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = Layout.minContentSize

        super.init(window: window)

        historyStore.onChange = { [weak self] _ in
            self?.reloadRows()
        }

        buildContent()
        applyLanguage()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func showClipboard() {
        applyLanguage()

        guard let window else {
            return
        }

        let shouldPositionAtTopLeft = !window.isVisible
        let shouldResetScroll = !window.isVisible
        reloadRows()
        fitWindowToHistory(positionAtTopLeft: shouldPositionAtTopLeft)

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        if shouldResetScroll {
            scrollToLatestItemAfterLayout()
        }
    }

    func applyLanguage() {
        let language = settings.language
        window?.title = text(language, korean: "클립보드 히스토리", english: "Clipboard History")
        titleLabel.stringValue = text(language, korean: "클립보드 히스토리", english: "Clipboard History")
        searchField.placeholderString = text(language, korean: "검색", english: "Search")
        refreshButton.title = text(language, korean: "새로고침", english: "Refresh")
        clearButton.title = text(language, korean: "히스토리 비우기", english: "Clear History")
        closeButton.title = text(language, korean: "닫기", english: "Close")
        reloadRows()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        CornerShotDesign.applyWindowBackground(to: contentView)

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = CornerShotDesign.Font.caption
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.controlSize = .regular
        searchField.font = CornerShotDesign.Font.body

        listStack.orientation = .vertical
        listStack.alignment = .width
        listStack.spacing = Layout.rowSpacing
        listStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.documentView = listStack

        for button in [refreshButton, clearButton, closeButton] {
            CornerShotDesign.applyQuietButtonStyle(button, controlSize: .regular)
        }

        let buttonStack = NSStackView(views: [clearButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = CornerShotDesign.Spacing.small

        for view in [titleLabel, refreshButton, detailLabel, searchField, scrollView, buttonStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        listStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentMargin),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: refreshButton.leadingAnchor, constant: -12),

            refreshButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentMargin),
            refreshButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: refreshButton.trailingAnchor),

            searchField.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: detailLabel.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: refreshButton.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentMargin),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentMargin),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),

            listStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        reloadRows()
    }

    @objc private func refresh() {
        historyStore.refresh()
        reloadRows()
    }

    @objc private func clearHistory() {
        historyStore.clear()
    }

    @objc private func closeClipboardWindow() {
        window?.close()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField,
              field === searchField else {
            return
        }

        searchQuery = field.stringValue
        reloadRows()
    }

    private func reloadRows() {
        guard isWindowLoaded else {
            return
        }

        let language = settings.language
        let allItems = historyStore.items
        let items = visibleItems(from: allItems)
        listStack.arrangedSubviews.forEach { view in
            listStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let pinnedCount = items.filter(\.isPinned).count
        detailLabel.stringValue = allItems.isEmpty
            ? text(language, korean: "복사한 항목이 아직 없습니다.", english: "No copied items yet.")
            : detailText(
                itemCount: items.count,
                totalCount: allItems.count,
                pinnedCount: pinnedCount,
                language: language
            )

        clearButton.isEnabled = allItems.contains { !$0.isPinned }

        guard !items.isEmpty else {
            let iconView = NSImageView()
            iconView.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard")
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            iconView.contentTintColor = .tertiaryLabelColor

            let isSearching = hasSearchQuery
            let emptyTitle = NSTextField(labelWithString: text(
                language,
                korean: isSearching ? "검색 결과가 없습니다." : "아직 기록된 항목이 없습니다.",
                english: isSearching ? "No matches." : "No history yet."
            ))
            emptyTitle.font = CornerShotDesign.Font.section
            emptyTitle.alignment = .center

            let emptyDetail = NSTextField(wrappingLabelWithString: text(
                language,
                korean: isSearching
                    ? "다른 키워드로 검색해보세요."
                    : "CornerShot이 실행된 뒤 복사한 항목이 여기에 쌓입니다.",
                english: isSearching
                    ? "Try a different keyword."
                    : "Items copied while CornerShot is running will appear here."
            ))
            emptyDetail.textColor = .secondaryLabelColor
            emptyDetail.font = CornerShotDesign.Font.body
            emptyDetail.alignment = .center

            let emptyStack = NSStackView(views: [iconView, emptyTitle, emptyDetail])
            emptyStack.orientation = .vertical
            emptyStack.alignment = .centerX
            emptyStack.spacing = CornerShotDesign.Spacing.small
            emptyStack.edgeInsets = NSEdgeInsets(top: 42, left: 16, bottom: 0, right: 16)
            listStack.addArrangedSubview(emptyStack)
            return
        }

        for item in items {
            let row = ClipboardHistoryRowView(
                item: item,
                language: language,
                onDelete: { [weak self] id in
                    self?.historyStore.deleteItem(id: id)
                },
                onTogglePinned: { [weak self] id in
                    self?.historyStore.togglePinned(id: id)
                }
            )
            row.translatesAutoresizingMaskIntoConstraints = false
            listStack.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: ClipboardHistoryRowView.rowHeight(for: item)).isActive = true
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }

    private var hasSearchQuery: Bool {
        !ClipboardHistoryItem.normalizedSearchText(searchQuery).isEmpty
    }

    private func visibleItems(from items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        guard hasSearchQuery else {
            return items
        }

        return items.filter { $0.matchesSearch(searchQuery) }
    }

    private func detailText(
        itemCount: Int,
        totalCount: Int,
        pinnedCount: Int,
        language: AppLanguage
    ) -> String {
        if hasSearchQuery {
            return text(
                language,
                korean: "\(totalCount)개 중 \(itemCount)개 검색 결과",
                english: "\(itemCount) of \(totalCount) result(s)"
            )
        }

        guard pinnedCount > 0 else {
            return text(
                language,
                korean: "\(itemCount)개 항목 · 최신 항목이 맨 위에 표시됩니다.",
                english: "\(itemCount) item(s) · Newest items appear at the top."
            )
        }

        return text(
            language,
            korean: "\(itemCount)개 항목 · \(pinnedCount)개 고정",
            english: "\(itemCount) item(s) · \(pinnedCount) pinned"
        )
    }

    private func scrollToLatestItemAfterLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.scrollToLatestItem()
        }
    }

    private func scrollToLatestItem() {
        listStack.layoutSubtreeIfNeeded()
        scrollView.layoutSubtreeIfNeeded()

        guard let documentView = scrollView.documentView else {
            return
        }

        let clipView = scrollView.contentView
        let documentBounds = documentView.bounds
        let targetY: CGFloat

        if documentView.isFlipped {
            targetY = documentBounds.minY
        } else {
            targetY = max(documentBounds.minY, documentBounds.maxY - clipView.bounds.height)
        }

        clipView.scroll(to: NSPoint(x: documentBounds.minX, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func fitWindowToHistory(positionAtTopLeft: Bool) {
        guard let window else {
            return
        }

        let screen = presentationScreen()
        var contentSize = preferredContentSize(for: visibleItems(from: historyStore.items), on: screen)
        let maxFrameWidth = max(Layout.minContentSize.width, screen.visibleFrame.width - (Layout.edgeMargin * 2))
        let maxFrameHeight = max(Layout.minContentSize.height, screen.visibleFrame.height - (Layout.edgeMargin * 2))

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        if frame.width > maxFrameWidth {
            contentSize.width -= frame.width - maxFrameWidth
        }
        if frame.height > maxFrameHeight {
            contentSize.height -= frame.height - maxFrameHeight
        }

        contentSize.width = max(Layout.minContentSize.width, contentSize.width)
        contentSize.height = max(Layout.minContentSize.height, contentSize.height)
        frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))

        if positionAtTopLeft {
            frame.origin = topLeftOrigin(for: frame.size, on: screen)
        } else {
            frame.origin = window.frame.origin
        }

        window.setFrame(frame, display: true, animate: false)
    }

    private func preferredContentSize(for items: [ClipboardHistoryItem], on screen: NSScreen) -> NSSize {
        let listHeight: CGFloat
        if items.isEmpty {
            listHeight = Layout.emptyListHeight
        } else {
            let visibleRowCount = min(items.count, Layout.maxVisibleRows)
            let rowsHeight = CGFloat(visibleRowCount) * ClipboardHistoryRowView.rowHeight
            let spacingHeight = CGFloat(max(visibleRowCount - 1, 0)) * Layout.rowSpacing
            listHeight = rowsHeight + spacingHeight + Layout.listVerticalInsets
        }

        let desiredHeight = Layout.baseContentHeight + listHeight
        let availableFrameHeight = screen.visibleFrame.height - (Layout.edgeMargin * 2)
        let maxContentHeight = max(
            Layout.minContentSize.height,
            min(620, availableFrameHeight - 32)
        )

        return NSSize(
            width: max(Layout.minContentSize.width, Layout.preferredContentWidth),
            height: min(max(Layout.minContentSize.height, desiredHeight), maxContentHeight)
        )
    }

    private func presentationScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first!
    }

    private func topLeftOrigin(for windowSize: NSSize, on screen: NSScreen) -> NSPoint {
        let visibleFrame = screen.visibleFrame
        return NSPoint(
            x: visibleFrame.minX + Layout.edgeMargin,
            y: visibleFrame.maxY - windowSize.height - Layout.edgeMargin
        )
    }
}
