import Foundation

/// Uniquely identifies a physical mouse device.
struct MouseDevice: Identifiable, Codable, Equatable, Hashable {
    /// Stable unique key: "VID_PID_SN" or "VID_PID_LOC" as fallback
    var id: String
    var vendorID: Int
    var productID: Int
    var serialNumber: String
    var name: String

    static func makeID(vendorID: Int, productID: Int, serialNumber: String, locationID: Int) -> String {
        let sn = serialNumber.trimmingCharacters(in: .whitespaces)
        if !sn.isEmpty {
            return String(format: "%04X_%04X_%@", vendorID, productID, sn)
        }
        return String(format: "%04X_%04X_LOC%d", vendorID, productID, locationID)
    }
    
    /// Returns true if two devices are considered the same based on vendorID, productID, and serialNumber
    static func isSameDevice(_ device1: MouseDevice, _ device2: MouseDevice) -> Bool {
        return device1.vendorID == device2.vendorID && 
               device1.productID == device2.productID && 
               device1.serialNumber.trimmingCharacters(in: .whitespaces) == device2.serialNumber.trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        name.isEmpty ? String(format: "鼠标 %04X:%04X", vendorID, productID) : name
    }
}
