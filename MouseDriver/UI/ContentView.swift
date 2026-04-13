import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: ConfigStore

    @State private var selection: UUID? = nil
    @State private var showAddSheet = false
    @State private var editMapping: ButtonMapping? = nil
    @State private var showDeleteDeviceAlert = false

    // Import state
    @State private var pendingImport: ConfigStore.DeviceExport? = nil
    @State private var showImportMergeAlert = false
    @State private var importError: String? = nil
    @State private var showImportErrorAlert = false

    private let typeLabels: [ActionType: String] = [
        .command:     "Shell Command",
        .shortcut:    "Shortcut",
        .keySequence: "Key Sequence",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Device selector ───────────────────────────────────────
            deviceSelectorView
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8)

            Divider()

            // ── Toolbar ───────────────────────────────────────────────
            HStack(spacing: 8) {
                Button("Add Mapping") { showAddSheet = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.activeDeviceID == nil)

                Button("Edit") { editSelected() }
                    .disabled(selection == nil)

                Button("Enable/Disable") { toggleSelected() }
                    .disabled(selection == nil)

                Button("Delete") { deleteSelected() }
                    .disabled(selection == nil)

                Spacer()

                Button("Import") { importConfig() }
                Button("Export") { exportConfig() }
                    .disabled(store.activeDeviceID == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // ── Mapping table ─────────────────────────────────────────
            if store.activeDeviceID == nil {
                Spacer()
                Text("Connect a mouse or select a device to get started")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                Table(store.mappings, selection: $selection) {
                    TableColumn("Mouse Button") { m in
                        Text(m.button).foregroundColor(m.enabled ? .primary : .secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editMapping = m }
                    }
                    .width(min: 80, ideal: 80)

                    TableColumn("Description") { m in
                        Text(m.note)
                            .foregroundColor(m.enabled ? .secondary : Color.secondary.opacity(0.5))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editMapping = m }
                    }.width(min: 80, ideal: 80)

                    TableColumn("Action") { m in
                        Text(m.actionValue)
                            .foregroundColor(m.enabled ? .primary : .secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editMapping = m }
                    }.width(min: 100, ideal: 200)

                    TableColumn("Type") { m in
                        Text(typeLabels[m.actionType] ?? m.actionType.rawValue)
                            .foregroundColor(m.enabled ? .primary : .secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editMapping = m }
                    }
                    .width(min: 100, ideal: 100)

                    TableColumn("Status") { m in
                        Text(m.enabled ? "✔ Enabled" : "✘ Disabled")
                            .foregroundColor(m.enabled ? .green : .secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editMapping = m }
                    }
                    .width(80)
                }
                .onDeleteCommand { deleteSelected() }
            }

            // ── Footer ────────────────────────────────────────────────
            Text("Tip: double-click a row to edit · the app continues running in the menu bar when the window is closed")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding([.horizontal, .bottom], 12)
                .padding(.top, 4)
        }
        .frame(minWidth: 700, minHeight: 460)
        .sheet(isPresented: $showAddSheet) {
            MappingEditView().environmentObject(store)
        }
        .sheet(item: $editMapping) { mapping in
            MappingEditView(existing: mapping).environmentObject(store)
        }
        .alert("Delete Device", isPresented: $showDeleteDeviceAlert) {
            Button("Delete", role: .destructive) {
                if let id = store.activeDeviceID { store.deleteDevice(id: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All mappings for this device will also be deleted and cannot be recovered.")
        }
        .alert("Import Config", isPresented: $showImportMergeAlert, presenting: pendingImport) { payload in
            Button("Replace Existing Mappings", role: .destructive) {
                applyImport(payload, strategy: .replace)
            }
            Button("Append to Existing Mappings") {
                applyImport(payload, strategy: .append)
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { payload in
            Text("The selected config will be applied to the currently active device.\nThis device already has mappings. How would you like to import?")
        }
        .alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Device selector

    @ViewBuilder
    private var deviceSelectorView: some View {
        HStack(spacing: 12) {
            Text("Device:")
                .fontWeight(.medium)

            if store.devices.isEmpty {
                Text("No mouse devices found")
                    .foregroundColor(.secondary)
            } else {
                Picker("", selection: Binding(
                    get: { store.activeDeviceID ?? "" },
                    set: { store.activeDeviceID = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(store.devices) { device in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.connectedDeviceIDs.contains(device.id) ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                            Text(device.displayName)
                        }
                        .tag(device.id)
                    }
                }
                .frame(maxWidth: 320)
                .labelsHidden()
            }

            Spacer()

            // Scan button
            Button {
                scanDevices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Scan for connected mouse devices")

            if let id = store.activeDeviceID {
                if store.connectedDeviceIDs.contains(id) {
                    Label("Connected", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Label("Disconnected", systemImage: "circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Button(role: .destructive) {
                    showDeleteDeviceAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete this device and all its mappings")
            }
        }
    }

    // MARK: - Scan devices

    private func scanDevices() {
        let found = MouseDeviceMonitor.shared.connectedDevices()
        for device in found {
            store.registerDevice(device)
            store.connectedDeviceIDs.insert(device.id)
        }
        if store.activeDeviceID == nil, let first = found.first {
            store.activeDeviceID = first.id
        }
    }

    // MARK: - Export

    private func exportConfig() {
        guard let deviceID = store.activeDeviceID else { return }
        guard let data = try? store.exportData(deviceID: deviceID) else { return }

        let deviceName = store.devices.first(where: { $0.id == deviceID })?.displayName ?? "device"
        let safeName = deviceName.replacingOccurrences(of: "/", with: "-")

        let panel = NSSavePanel()
        panel.title = "Export Mouse Config"
        panel.nameFieldStringValue = "\(safeName).mousecfg"
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Import

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Import Mouse Config"
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(ConfigStore.DeviceExport.self, from: data)

            // Check if active device has existing mappings
            if let activeDeviceID = store.activeDeviceID, !(store.deviceMappings[activeDeviceID]?.isEmpty ?? true) {
                pendingImport = payload
                showImportMergeAlert = true
            } else {
                applyImport(payload, strategy: .replace)
            }
        } catch {
            importError = error.localizedDescription
            showImportErrorAlert = true
        }
    }

    private func applyImport(_ payload: ConfigStore.DeviceExport,
                              strategy: ConfigStore.ImportMergeStrategy) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            _ = try store.importData(data, mergeStrategy: strategy)
            pendingImport = nil
        } catch {
            importError = error.localizedDescription
            showImportErrorAlert = true
        }
    }

    // MARK: - Mapping actions

    private func editSelected() {
        guard let id = selection,
              let mapping = store.mappings.first(where: { $0.id == id }) else { return }
        editMapping = mapping
    }

    private func toggleSelected() {
        guard let id = selection else { return }
        store.toggle(id: id)
    }

    private func deleteSelected() {
        guard let id = selection else { return }
        store.delete(id: id)
        selection = nil
    }
}
