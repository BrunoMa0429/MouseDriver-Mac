import Cocoa
import ApplicationServices

/// All public methods must be called on the main thread.
final class MouseTapService {
    static let shared = MouseTapService()

    /// Called on the main thread when a mapped button is pressed (non-capture mode).
    var onButtonPress: ((String) -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // One-shot capture
    private var captureCallback: ((String) -> Void)?
    private var captureTimer: Timer?

    private init() {}

    // MARK: - Permission

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }
        if !MouseTapService.isAccessibilityGranted() {
            MouseTapService.requestAccessibilityPermission()
            // Retry after a short delay to handle case where user just granted permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.start()
            }
            return
        }
        createTap()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - One-shot capture

    func startCapture(timeout: TimeInterval = 3, completion: @escaping (String) -> Void) {
        captureTimer?.invalidate()
        captureCallback = completion

        // Ensure tap is running (might not be if permission was just granted)
        if eventTap == nil {
            createTap()
        }

        captureTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.captureCallback = nil
        }
    }

    func cancelCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        captureCallback = nil
    }

    // MARK: - CGEventTap

    private func createTap() {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        // Use a raw pointer to avoid retain-cycle through C callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("[MouseTapService] CGEventTap 创建失败 — 请在系统设置→隐私→辅助功能中授权本应用")
            return
        }

        print("[MouseTapService] CGEventTap 创建成功")
        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) {
        // Filter out trackpad clicks — they appear as mouseEventSubtype == tabletPoint (1)
        // Real mouse clicks have subtype == mouseEventNotification (0)
        let subtype = event.getIntegerValueField(.mouseEventSubtype)
        guard subtype == 0 else { return }

        let n = event.getIntegerValueField(.mouseEventButtonNumber)
        let name: String
        switch n {
        case 0: name = "left"
        case 1: name = "right"
        case 2: name = "middle"
        default: name = "button_\(n)"
        }

        // CGEventTap callback runs on the main runloop (we added it to CFRunLoopGetMain),
        // so we are already on the main thread here.
        if let cb = captureCallback {
            captureTimer?.invalidate()
            captureTimer = nil
            captureCallback = nil
            cb(name)
            return
        }
        onButtonPress?(name)
    }
}

// MARK: - C-compatible callback (must be a free function)

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    // tapEnable/disable events — re-enable if the OS disabled it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        let service = Unmanaged<MouseTapService>.fromOpaque(userInfo).takeUnretainedValue()
        if let tap = service.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }
    let service = Unmanaged<MouseTapService>.fromOpaque(userInfo).takeUnretainedValue()
    service.handleEvent(type: type, event: event)
    return Unmanaged.passRetained(event)
}
