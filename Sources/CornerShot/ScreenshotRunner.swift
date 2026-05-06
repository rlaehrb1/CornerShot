import AppKit
import Foundation

final class ScreenshotRunner {
    private let settings: Settings
    private let previewController = ScreenshotPreviewController()
    private var isCapturing = false

    init(settings: Settings) {
        self.settings = settings
    }

    func capture(mode: CaptureMode, completion: @escaping () -> Void) {
        guard !isCapturing else {
            completion()
            return
        }

        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            completion()
            return
        }

        isCapturing = true

        let outputURL = settings.screenshotDirectoryURL
            .appendingPathComponent(filename())
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            isCapturing = false
            showSaveFailure(for: outputURL, error: error)
            completion()
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = mode.commandArguments + [outputURL.path]
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.showPreviewIfNeeded(for: outputURL, process: process)
                completion()
            }
        }

        do {
            try process.run()
        } catch {
            isCapturing = false
            showSaveFailure(for: outputURL, error: error)
            completion()
        }
    }

    private func showPreviewIfNeeded(for outputURL: URL, process: Process) {
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            if process.terminationStatus != 0 {
                showSaveFailure(for: outputURL, error: nil)
            }
            return
        }

        previewController.showPreview(for: outputURL)
    }

    private func showSaveFailure(for outputURL: URL, error: Error?) {
        let message: String
        if let error {
            message = "\(outputURL.deletingLastPathComponent().path)\n\n\(error.localizedDescription)"
        } else {
            message = outputURL.deletingLastPathComponent().path
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text(
            settings.language,
            korean: "CornerShot 스크린샷을 저장하지 못했습니다.",
            english: "CornerShot could not save the screenshot."
        )
        alert.informativeText = text(
            settings.language,
            korean: "저장 위치를 확인한 뒤 다시 시도하세요.\n\n\(message)",
            english: "Check the save location, then try again.\n\n\(message)"
        )
        alert.addButton(withTitle: text(settings.language, korean: "확인", english: "OK"))
        alert.runModal()
    }

    private func filename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let suffix = UUID().uuidString.prefix(6)
        return "CornerShot \(formatter.string(from: Date())) \(suffix).png"
    }
}

final class ScreenshotPreviewController {
    private enum Layout {
        static let windowSize = NSSize(width: 178, height: 118)
        static let imageInset: CGFloat = 8
        static let edgeMargin: CGFloat = 24
        static let displayDuration: TimeInterval = 5
    }

    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func showPreview(for fileURL: URL) {
        guard let image = NSImage(contentsOf: fileURL) else {
            return
        }

        dismissWorkItem?.cancel()

        let window = makeWindowIfNeeded()
        configure(window: window, image: image, fileURL: fileURL)
        position(window: window)

        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 1
        }

        scheduleDismiss(for: window)
    }

    private func makeWindowIfNeeded() -> NSPanel {
        if let window {
            return window
        }

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.minSize = Layout.windowSize
        window.maxSize = Layout.windowSize
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        self.window = window
        return window
    }

    private func configure(window: NSPanel, image: NSImage, fileURL: URL) {
        let contentView = ScreenshotPreviewView(
            fileURL: fileURL,
            onDragStarted: { [weak self] in
                self?.dismissWorkItem?.cancel()
                self?.dismissWorkItem = nil
            },
            onDragEnded: { [weak self, weak window] completed in
                guard let self, let window else {
                    return
                }

                if completed {
                    self.dismiss(window: window)
                } else {
                    self.scheduleDismiss(for: window)
                }
            }
        )
        contentView.frame = NSRect(origin: .zero, size: Layout.windowSize)
        contentView.translatesAutoresizingMaskIntoConstraints = true
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = CornerShotDesign.elevatedSurfaceColor
            .withAlphaComponent(0.96)
            .cgColor
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = CornerShotDesign.borderColor.cgColor
        contentView.layer?.cornerRadius = CornerShotDesign.Radius.large
        contentView.layer?.masksToBounds = true

        let imageView = NSImageView(frame: .zero)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        imageView.layer?.cornerRadius = CornerShotDesign.Radius.medium
        imageView.layer?.masksToBounds = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.imageInset),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.imageInset),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.imageInset),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.imageInset)
        ])

        window.contentView = contentView
        window.setContentSize(Layout.windowSize)
    }

    private func position(window: NSPanel) {
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let visibleFrame = screen?.visibleFrame else {
            return
        }

        window.setFrame(
            NSRect(
                x: visibleFrame.maxX - Layout.windowSize.width - Layout.edgeMargin,
                y: visibleFrame.minY + Layout.edgeMargin,
                width: Layout.windowSize.width,
                height: Layout.windowSize.height
            ),
            display: true
        )
    }

    private func dismiss(window: NSPanel?) {
        guard let window else {
            return
        }

        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    private func scheduleDismiss(for window: NSPanel) {
        dismissWorkItem?.cancel()

        let dismissWorkItem = DispatchWorkItem { [weak self, weak window] in
            self?.dismiss(window: window)
        }
        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Layout.displayDuration,
            execute: dismissWorkItem
        )
    }
}

final class ScreenshotPreviewView: NSView, NSDraggingSource {
    private let fileURL: URL
    private let onDragStarted: () -> Void
    private let onDragEnded: (Bool) -> Void
    private var mouseDownEvent: NSEvent?
    private var didStartDrag = false

    init(
        fileURL: URL,
        onDragStarted: @escaping () -> Void,
        onDragEnded: @escaping (Bool) -> Void
    ) {
        self.fileURL = fileURL
        self.onDragStarted = onDragStarted
        self.onDragEnded = onDragEnded
        super.init(frame: .zero)
        toolTip = fileURL.path
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag,
              let mouseDownEvent,
              event.locationInWindow.distance(to: mouseDownEvent.locationInWindow) > 4 else {
            return
        }

        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        draggingItem.setDraggingFrame(bounds, contents: draggingImage())
        didStartDrag = true
        onDragStarted()
        beginDraggingSession(with: [draggingItem], event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !didStartDrag else {
            mouseDownEvent = nil
            didStartDrag = false
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
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
        didStartDrag = false
        onDragEnded(!operation.isEmpty)
    }

    private func draggingImage() -> NSImage {
        guard bounds.width > 0, bounds.height > 0,
              let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return NSWorkspace.shared.icon(forFile: fileURL.path)
        }

        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
