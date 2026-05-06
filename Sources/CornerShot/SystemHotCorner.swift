import AppKit
import Foundation

struct SystemHotCornerState {
    let actionValue: Int
    let modifierValue: Int

    var isAssigned: Bool {
        actionValue > 1
    }

    var blocksPlainMouseTrigger: Bool {
        isAssigned && modifierValue == 0
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if modifierValue & 262_144 != 0 {
            flags.insert(.control)
        }
        if modifierValue & 524_288 != 0 {
            flags.insert(.option)
        }
        if modifierValue & 1_048_576 != 0 {
            flags.insert(.command)
        }
        if modifierValue & 131_072 != 0 {
            flags.insert(.shift)
        }

        return flags
    }

    func blocksMouseTrigger(currentModifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard isAssigned else {
            return false
        }

        if blocksPlainMouseTrigger {
            return true
        }

        let requiredModifierFlags = modifierFlags
        guard !requiredModifierFlags.isEmpty else {
            return false
        }

        let activeModifierFlags = currentModifierFlags.intersection(.deviceIndependentFlagsMask)
        return activeModifierFlags.intersection(requiredModifierFlags) == requiredModifierFlags
    }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        guard isAssigned else {
            return text(language, korean: "macOS: 없음", english: "macOS: None")
        }

        let modifier = modifierSymbols(language: language)
        if modifier.isEmpty {
            return "macOS: \(systemActionTitle(language: language))"
        }

        return "macOS: \(modifier) \(systemActionTitle(language: language))"
    }

    var status: String {
        status(language: .english)
    }

    func status(language: AppLanguage) -> String {
        guard isAssigned else {
            return text(
                language,
                korean: "CornerShot에서 바로 사용할 수 있습니다.",
                english: "Available for CornerShot."
            )
        }

        if blocksPlainMouseTrigger {
            return text(
                language,
                korean: "충돌: macOS 핫코너를 비우기 전까지 여기서는 실행하지 않습니다.",
                english: "Conflict: CornerShot is paused here until the macOS corner is cleared."
            )
        }

        return text(
            language,
            korean: "macOS는 \(modifierSymbols(language: language)) 키를 누를 때만 사용하므로 일반 마우스 이동은 사용할 수 있습니다.",
            english: "macOS uses this only with \(modifierSymbols(language: language)), so plain mouse movement is available."
        )
    }

    private func systemActionTitle(language: AppLanguage) -> String {
        switch actionValue {
        case 2:
            text(language, korean: "Mission Control", english: "Mission Control")
        case 3:
            text(language, korean: "응용 프로그램 윈도우", english: "Application Windows")
        case 4:
            text(language, korean: "데스크탑", english: "Desktop")
        case 5:
            text(language, korean: "화면 보호기 시작", english: "Start Screen Saver")
        case 6:
            text(language, korean: "화면 보호기 비활성화", english: "Disable Screen Saver")
        case 7:
            text(language, korean: "Dashboard", english: "Dashboard")
        case 10:
            text(language, korean: "디스플레이 잠자기", english: "Put Display to Sleep")
        case 11:
            text(language, korean: "Launchpad", english: "Launchpad")
        case 12:
            text(language, korean: "알림 센터", english: "Notification Center")
        case 13:
            text(language, korean: "화면 잠금", english: "Lock Screen")
        case 14:
            text(language, korean: "빠른 메모", english: "Quick Note")
        default:
            text(language, korean: "알 수 없는 동작 (\(actionValue))", english: "Unknown Action (\(actionValue))")
        }
    }

    private func modifierSymbols(language: AppLanguage) -> String {
        var symbols: [String] = []

        if modifierValue & 262_144 != 0 {
            symbols.append("Control")
        }
        if modifierValue & 524_288 != 0 {
            symbols.append("Option")
        }
        if modifierValue & 1_048_576 != 0 {
            symbols.append("Command")
        }
        if modifierValue & 131_072 != 0 {
            symbols.append("Shift")
        }

        return symbols.joined(separator: text(language, korean: " + ", english: " + "))
    }
}

final class SystemHotCornerReader {
    func state(for corner: HotCorner) -> SystemHotCornerState {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        return SystemHotCornerState(
            actionValue: readInt(corner.actionDefaultsKey) ?? 0,
            modifierValue: readInt(corner.modifierDefaultsKey) ?? 0
        )
    }

    private func readInt(_ key: String) -> Int? {
        let domain = "com.apple.dock" as CFString
        guard let value = CFPreferencesCopyAppValue(key as CFString, domain) else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        if let string = value as? String {
            return Int(string)
        }

        return nil
    }
}
