import Cocoa
import Carbon

/// Records the next key combination pressed globally and returns it as a shortcut string.
/// e.g. "cmd+shift+4", "ctrl+c", "f5"
/// Must be called on the main thread.
final class KeyboardRecorder {
    static let shared = KeyboardRecorder()
    private init() {}

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var isRecording = false
    private var onCancel: (() -> Void)?

    /// - Parameters:
    ///   - completion: Called with the recorded shortcut string.
    ///   - onCancel:   Called when user presses Esc to cancel (without recording).
    func startRecording(completion: @escaping (String) -> Void,
                        onCancel: (() -> Void)? = nil) {
        stopRecording()
        isRecording = true
        self.onCancel = onCancel

        // Local monitor: fires when this app has focus (the recording sheet is open).
        // Returning nil consumes the event so SwiftUI / AppKit never see it.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.isRecording else { return event }

            // Esc without modifiers → cancel recording
            if event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.stopRecording()
                DispatchQueue.main.async { onCancel?() }
                return nil  // Consume Esc so the sheet doesn't close
            }

            // Ignore lone modifier keys (no real key code paired)
            let pureModifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !pureModifiers.contains(event.keyCode) else { return nil }

            let shortcut = Self.shortcutString(from: event)
            self.stopRecording()
            DispatchQueue.main.async { completion(shortcut) }
            return nil  // Consume — prevent default action (e.g. Enter confirming form)
        }

        // Global monitor: fires when another app has focus.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.isRecording else { return }
            let pureModifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !pureModifiers.contains(event.keyCode) else { return }
            let shortcut = Self.shortcutString(from: event)
            self.stopRecording()
            DispatchQueue.main.async { completion(shortcut) }
        }
    }

    func stopRecording() {
        isRecording = false
        onCancel = nil
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    // MARK: - Convert NSEvent → shortcut string

    private static func shortcutString(from event: NSEvent) -> String {
        var parts: [String] = []

        let flags = event.modifierFlags
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option)  { parts.append("alt") }
        if flags.contains(.shift)   { parts.append("shift") }
        if flags.contains(.command) { parts.append("cmd") }

        let keyName = keyNameFromKeyCode(event.keyCode)
        parts.append(keyName)

        return parts.joined(separator: "+")
    }

    private static func keyNameFromKeyCode(_ keyCode: UInt16) -> String {
        let table: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: ".", 50: "`",
            36: "enter", 48: "tab", 49: "space", 51: "backspace", 53: "esc",
            96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9",
            103: "f11", 105: "f13", 109: "f10", 111: "f12", 115: "home",
            116: "page_up", 117: "delete", 119: "end", 121: "page_down",
            122: "f1", 123: "left", 124: "right", 125: "down", 126: "up",
            120: "f2", 118: "f4",
        ]
        return table[keyCode] ?? "key\(keyCode)"
    }
}
