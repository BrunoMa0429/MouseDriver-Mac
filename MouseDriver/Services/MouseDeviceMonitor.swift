import IOKit
import IOKit.hid
import Foundation

/// Monitors HID mouse device connect/disconnect events via IOHIDManager.
/// All callbacks are dispatched to the main thread.
final class MouseDeviceMonitor {
    static let shared = MouseDeviceMonitor()

    var onDeviceConnected: ((MouseDevice) -> Void)?
    var onDeviceDisconnected: ((MouseDevice) -> Void)?

    private var hidManager: IOHIDManager?
    private init() {}

    // MARK: - Lifecycle

    func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager

        // Match all mice (Generic Desktop / Mouse)
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey:     kHIDUsage_GD_Mouse,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            let monitor = Unmanaged<MouseDeviceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            if let dev = MouseDeviceMonitor.deviceInfo(device) {
                DispatchQueue.main.async { monitor.onDeviceConnected?(dev) }
            }
        }, selfPtr)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            let monitor = Unmanaged<MouseDeviceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            if let dev = MouseDeviceMonitor.deviceInfo(device) {
                DispatchQueue.main.async { monitor.onDeviceDisconnected?(dev) }
            }
        }, selfPtr)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
    }

    // MARK: - Currently connected mice

    func connectedDevices() -> [MouseDevice] {
        guard let manager = hidManager,
              let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.compactMap { MouseDeviceMonitor.deviceInfo($0) }
    }

    // MARK: - Helpers

    static func deviceInfo(_ device: IOHIDDevice) -> MouseDevice? {
        func prop<T>(_ key: String) -> T? {
            IOHIDDeviceGetProperty(device, key as CFString) as? T
        }
        guard let vid: Int = prop(kIOHIDVendorIDKey),
              let pid: Int = prop(kIOHIDProductIDKey) else { return nil }

        let sn: String  = prop(kIOHIDSerialNumberKey) ?? ""
        let loc: Int    = prop(kIOHIDLocationIDKey)   ?? 0
        let name: String = prop(kIOHIDProductKey)     ?? ""

        return MouseDevice(
            id:           MouseDevice.makeID(vendorID: vid, productID: pid, serialNumber: sn, locationID: loc),
            vendorID:     vid,
            productID:    pid,
            serialNumber: sn,
            name:         name
        )
    }
}
