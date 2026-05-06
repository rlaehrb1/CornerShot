import Foundation

enum CaptureMode: String, CaseIterable {
    case fullScreen
    case window
    case selection

    var commandArguments: [String] {
        switch self {
        case .fullScreen:
            []
        case .window:
            ["-i", "-w"]
        case .selection:
            ["-i", "-s"]
        }
    }
}

enum CornerAction: String, CaseIterable {
    case none
    case screenshotFullScreen
    case screenshotWindow
    case screenshotSelection
    case showClipboard

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .none:
            text(language, korean: "없음", english: "None")
        case .screenshotFullScreen:
            text(language, korean: "스크린샷: 전체 화면", english: "Screenshot: Full Screen")
        case .screenshotWindow:
            text(language, korean: "스크린샷: 선택한 윈도우", english: "Screenshot: Selected Window")
        case .screenshotSelection:
            text(language, korean: "스크린샷: 선택 영역", english: "Screenshot: Selected Area")
        case .showClipboard:
            text(language, korean: "클립보드 창 보기", english: "Show Clipboard Window")
        }
    }

    var captureMode: CaptureMode? {
        switch self {
        case .screenshotFullScreen: .fullScreen
        case .screenshotWindow: .window
        case .screenshotSelection: .selection
        case .none, .showClipboard: nil
        }
    }

    var isRunnable: Bool {
        self != .none
    }

    static func screenshotAction(for mode: CaptureMode) -> CornerAction {
        switch mode {
        case .fullScreen: .screenshotFullScreen
        case .window: .screenshotWindow
        case .selection: .screenshotSelection
        }
    }
}

enum HotCorner: String, CaseIterable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .topLeft:
            text(language, korean: "왼쪽 위", english: "Top Left")
        case .topRight:
            text(language, korean: "오른쪽 위", english: "Top Right")
        case .bottomLeft:
            text(language, korean: "왼쪽 아래", english: "Bottom Left")
        case .bottomRight:
            text(language, korean: "오른쪽 아래", english: "Bottom Right")
        }
    }

    var shortTitle: String {
        switch self {
        case .topLeft: "TL"
        case .topRight: "TR"
        case .bottomLeft: "BL"
        case .bottomRight: "BR"
        }
    }

    var actionDefaultsKey: String {
        switch self {
        case .topLeft: "wvous-tl-corner"
        case .topRight: "wvous-tr-corner"
        case .bottomLeft: "wvous-bl-corner"
        case .bottomRight: "wvous-br-corner"
        }
    }

    var modifierDefaultsKey: String {
        switch self {
        case .topLeft: "wvous-tl-modifier"
        case .topRight: "wvous-tr-modifier"
        case .bottomLeft: "wvous-bl-modifier"
        case .bottomRight: "wvous-br-modifier"
        }
    }
}
