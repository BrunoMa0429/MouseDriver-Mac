import Foundation
import Combine

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    // All known devices (ever seen)
    @Published var devices: [MouseDevice] = []

    // Currently selected device in the UI
    @Published var activeDeviceID: String? = nil

    // Mappings keyed by device ID
    @Published private(set) var deviceMappings: [String: [ButtonMapping]] = [:]

    // Connected devices (updated by MouseDeviceMonitor)
    @Published var connectedDeviceIDs: Set<String> = []

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("MouseDriver", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config_v2.json")
    }()

    private init() { load() }

    // MARK: - Active mappings (for current device)

    var mappings: [ButtonMapping] {
        guard let id = activeDeviceID else { return [] }
        return deviceMappings[id] ?? []
    }

    func mapping(for button: String) -> ButtonMapping? {
        mappings.first { $0.button == button && $0.enabled }
    }

    // MARK: - Device management

    func registerDevice(_ device: MouseDevice) {
        // Check if there's an existing device with the same vendorID, productID, and serialNumber
        if let existingDevice = devices.first(where: { MouseDevice.isSameDevice($0, device) }) {
            // Use the existing device's ID to share the same configuration
            let updatedDevice = MouseDevice(
                id: existingDevice.id,
                vendorID: device.vendorID,
                productID: device.productID,
                serialNumber: device.serialNumber,
                name: device.name
            )
            // Update the existing device with the new information
            if let idx = devices.firstIndex(where: { $0.id == existingDevice.id }) {
                devices[idx] = updatedDevice
                save()
            }
        } else if !devices.contains(where: { $0.id == device.id }) {
            // No existing device with the same vendorID, productID, and serialNumber, and no device with the same ID
            devices.append(device)
            save()
        } else {
            // Device with the same ID already exists, update its information
            if let idx = devices.firstIndex(where: { $0.id == device.id }) {
                devices[idx] = device
                save()
            }
        }
    }

    func deleteDevice(id: String) {
        devices.removeAll { $0.id == id }
        deviceMappings.removeValue(forKey: id)
        if activeDeviceID == id {
            activeDeviceID = devices.first?.id
        }
        save()
    }

    // MARK: - CRUD for active device mappings

    func add(_ mapping: ButtonMapping) {
        guard let id = activeDeviceID else { return }
        deviceMappings[id, default: []].append(mapping)
        save()
    }

    func update(_ mapping: ButtonMapping) {
        guard let id = activeDeviceID,
              let idx = deviceMappings[id]?.firstIndex(where: { $0.id == mapping.id }) else { return }
        deviceMappings[id]![idx] = mapping
        save()
    }

    func delete(id mappingID: UUID) {
        guard let id = activeDeviceID else { return }
        deviceMappings[id]?.removeAll { $0.id == mappingID }
        save()
    }

    func toggle(id mappingID: UUID) {
        guard let id = activeDeviceID,
              let idx = deviceMappings[id]?.firstIndex(where: { $0.id == mappingID }) else { return }
        deviceMappings[id]![idx].enabled.toggle()
        save()
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            migrateFromV1()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let wrapper = try JSONDecoder().decode(StoreWrapper.self, from: data)
            devices       = wrapper.devices
            deviceMappings = wrapper.deviceMappings
            activeDeviceID = wrapper.activeDeviceID ?? devices.first?.id
        } catch {
            print("Failed to load config: \(error)")
        }
    }

    func save() {
        do {
            let wrapper = StoreWrapper(
                devices:        devices,
                deviceMappings: deviceMappings,
                activeDeviceID: activeDeviceID
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(wrapper)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    // Migrate old single-device config to new format under a "default" device
    private func migrateFromV1() {
        let v1URL = fileURL.deletingLastPathComponent().appendingPathComponent("button_mappings.json")
        guard FileManager.default.fileExists(atPath: v1URL.path),
              let data = try? Data(contentsOf: v1URL),
              let wrapper = try? JSONDecoder().decode(V1Wrapper.self, from: data),
              !wrapper.mappings.isEmpty else { return }

        let defaultDevice = MouseDevice(
            id: "default",
            vendorID: 0, productID: 0,
            serialNumber: "",
            name: "Default Device"
        )
        devices = [defaultDevice]
        deviceMappings = ["default": wrapper.mappings]
        activeDeviceID = "default"
        save()
    }

    // MARK: - Export / Import

    /// Returns JSON data for the given device's mappings.
    func exportData(deviceID: String) throws -> Data {
        guard devices.contains(where: { $0.id == deviceID }) else {
            throw ExportError.deviceNotFound
        }
        let payload = DeviceExport(
            mappings: deviceMappings[deviceID] ?? []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    /// Imports a previously exported JSON to the active device.
    /// - Returns: The device ID of the active device.
    @discardableResult
    func importData(_ data: Data, mergeStrategy: ImportMergeStrategy) throws -> String {
        guard let activeDeviceID = self.activeDeviceID else {
            throw ExportError.deviceNotFound
        }
        
        let payload = try JSONDecoder().decode(DeviceExport.self, from: data)

        switch mergeStrategy {
        case .replace:
            deviceMappings[activeDeviceID] = payload.mappings

        case .append:
            var existing = deviceMappings[activeDeviceID] ?? []
            for m in payload.mappings {
                if !existing.contains(where: { $0.id == m.id }) {
                    existing.append(m)
                }
            }
            deviceMappings[activeDeviceID] = existing
        }

        save()
        return activeDeviceID
    }

    enum ExportError: LocalizedError {
        case deviceNotFound
        var errorDescription: String? { "Device not found" }
    }

    enum ImportMergeStrategy {
        case replace   // Overwrite existing mappings for this device
        case append    // Keep existing, add new ones
    }

    // Codable payload for a single device export file
    struct DeviceExport: Codable {
        var mappings: [ButtonMapping]
    }

    // MARK: - Codable wrappers

    private struct StoreWrapper: Codable {
        var devices: [MouseDevice]
        var deviceMappings: [String: [ButtonMapping]]
        var activeDeviceID: String?
    }

    private struct V1Wrapper: Codable {
        var mappings: [ButtonMapping]
    }
}
