import Cocoa
import Carbon

final class ActionExecutor {
    static let shared = ActionExecutor()
    private init() {}

    func execute(mapping: ButtonMapping) {
        print("[ActionExecutor] execute type=\(mapping.actionType.rawValue) value=\(mapping.actionValue)")
        switch mapping.actionType {
        case .command:     executeCommand(mapping.actionValue)
        case .shortcut:    executeShortcut(mapping.actionValue)
        case .keySequence: executeKeySequence(mapping.actionValue)
        }
    }

    // MARK: - Shell command

    private func executeCommand(_ command: String) {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice
        do { try process.run() } catch { print("执行命令失败: \(error)") }
    }

    // MARK: - Keyboard shortcut (e.g. "cmd+shift+4")

    private func executeShortcut(_ shortcut: String) {
        let parts = shortcut.lowercased().components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }

        var flags: CGEventFlags = []
        var keyCodes: [CGKeyCode] = []

        for part in parts {
            switch part {
            case "cmd", "command":  flags.insert(.maskCommand)
            case "ctrl", "control": flags.insert(.maskControl)
            case "shift":           flags.insert(.maskShift)
            case "alt", "opt", "option": flags.insert(.maskAlternate)
            default:
                if let code = keyCode(for: part) {
                    keyCodes.append(code)
                }
            }
        }

        let src = CGEventSource(stateID: .hidSystemState)
        for code in keyCodes {
            let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
            down?.flags = flags
            up?.flags   = flags
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Key sequence (e.g. "h,e,l,l,o" or "enter,tab")

    private func executeKeySequence(_ sequence: String) {
        let keys = sequence.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        DispatchQueue.global(qos: .userInitiated).async {
            let src = CGEventSource(stateID: .hidSystemState)
            for key in keys {
                if let code = self.keyCode(for: key.lowercased()) {
                    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
                    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
                } else {
                    // Treat as literal character
                    for char in key.unicodeScalars {
                        let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
                        down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.value)])
                        down?.post(tap: .cghidEventTap)
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    // MARK: - Key code lookup

    private func keyCode(for name: String) -> CGKeyCode? {
        let table: [String: CGKeyCode] = [
            "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,  "z": 6,  "x": 7,
            "c": 8,  "v": 9,  "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16,
            "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24,
            "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32,
            "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41,
            "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50,
            "enter": 36, "tab": 48, "space": 49, "backspace": 51, "delete": 51,
            "esc": 53, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99,  "f4": 118,
            "f5": 96,  "f6": 97,  "f7": 98,  "f8": 100,
            "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "home": 115, "end": 119, "pageup": 116, "page_up": 116,
            "pagedown": 121, "page_down": 121,
        ]
        return table[name]
    }
}
