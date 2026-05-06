import AppKit
import Foundation

final class HotCornerActionRunner {
    private let screenshotRunner: ScreenshotRunner
    private let clipboardWindowController: ClipboardWindowController

    init(
        screenshotRunner: ScreenshotRunner,
        clipboardWindowController: ClipboardWindowController
    ) {
        self.screenshotRunner = screenshotRunner
        self.clipboardWindowController = clipboardWindowController
    }

    func run(action: CornerAction, completion: @escaping () -> Void) {
        guard action.isRunnable else {
            completion()
            return
        }

        if let captureMode = action.captureMode {
            screenshotRunner.capture(mode: captureMode, completion: completion)
            return
        }

        switch action {
        case .showClipboard:
            clipboardWindowController.showClipboard()
            completion()
        case .none, .screenshotFullScreen, .screenshotWindow, .screenshotSelection:
            completion()
        }
    }
}

final class CornerMonitor {
    private let settings: Settings
    private let systemHotCornerReader: SystemHotCornerReader
    private let runner: HotCornerActionRunner
    private var timer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var armedCorners = Set(HotCorner.allCases)
    private var isWaitingForAction = false
    private let triggerSize: CGFloat = 14

    init(
        settings: Settings,
        systemHotCornerReader: SystemHotCornerReader,
        runner: HotCornerActionRunner
    ) {
        self.settings = settings
        self.systemHotCornerReader = systemHotCornerReader
        self.runner = runner
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        timer?.invalidate()
    }

    func start() {
        timer?.invalidate()
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }

        let mouseEvents: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            self?.tick()
            return event
        }

        let timer = Timer(
            timeInterval: 0.05,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard settings.isEnabled, !isWaitingForAction else {
            return
        }

        let point = NSEvent.mouseLocation
        guard let corner = hotCorner(containing: point) else {
            armedCorners = Set(HotCorner.allCases)
            return
        }

        guard armedCorners.contains(corner) else {
            return
        }

        let action = settings.action(for: corner)
        guard action.isRunnable else {
            return
        }

        let systemState = systemHotCornerReader.state(for: corner)
        guard !systemState.blocksMouseTrigger(currentModifierFlags: NSEvent.modifierFlags) else {
            armedCorners.remove(corner)
            return
        }

        armedCorners.remove(corner)
        isWaitingForAction = true

        runner.run(action: action) { [weak self] in
            self?.isWaitingForAction = false
        }
    }

    private func hotCorner(containing point: NSPoint) -> HotCorner? {
        guard let screen = screen(containing: point) else {
            return nil
        }

        let frame = screen.frame

        if point.x <= frame.minX + triggerSize && point.y >= frame.maxY - triggerSize {
            return .topLeft
        }

        if point.x >= frame.maxX - triggerSize && point.y >= frame.maxY - triggerSize {
            return .topRight
        }

        if point.x <= frame.minX + triggerSize && point.y <= frame.minY + triggerSize {
            return .bottomLeft
        }

        if point.x >= frame.maxX - triggerSize && point.y <= frame.minY + triggerSize {
            return .bottomRight
        }

        return nil
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.insetBy(dx: -triggerSize, dy: -triggerSize).contains(point)
        }
    }
}
