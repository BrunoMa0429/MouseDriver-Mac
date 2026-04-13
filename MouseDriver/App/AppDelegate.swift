import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var configWindow: NSWindow?
    private var store: ConfigStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = ConfigStore.shared
        setupStatusItem()
        setupDeviceMonitor()
        setupMouseTap()

        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
            NSApp.activate(ignoringOtherApps: false)
        }

        showConfig()
    }

    // MARK: - Status bar icon

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let img = NSImage(systemSymbolName: "computermouse",
                                 accessibilityDescription: "MouseDriver") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "M"
            }
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open MouseDriver", action: #selector(showConfig), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    // MARK: - Device monitor

    private func setupDeviceMonitor() {
        let store = self.store!
        let monitor = MouseDeviceMonitor.shared

        monitor.onDeviceConnected = { device in
            store.registerDevice(device)
            store.connectedDeviceIDs.insert(device.id)
            // Auto-select first connected device if none selected
            if store.activeDeviceID == nil {
                store.activeDeviceID = device.id
            }
        }

        monitor.onDeviceDisconnected = { device in
            store.connectedDeviceIDs.remove(device.id)
        }

        monitor.start()

        // Seed currently connected devices
        for device in monitor.connectedDevices() {
            store.registerDevice(device)
            store.connectedDeviceIDs.insert(device.id)
        }
        if store.activeDeviceID == nil {
            store.activeDeviceID = store.devices.first?.id
        }
    }

    // MARK: - Config window

    @objc func showConfig() {
        if configWindow == nil {
            let controller = NSHostingController(
                rootView: ContentView().environmentObject(store)
            )
            let window = NSWindow(contentViewController: controller)
            window.title = "MouseDriver"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 720, height: 500))
            window.center()
            window.setFrameAutosaveName("ConfigWindow")
            window.delegate = self
            window.isReleasedWhenClosed = false
            configWindow = window
        }
        configWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Mouse tap

    private func setupMouseTap() {
        let store = self.store!
        MouseTapService.shared.onButtonPress = { buttonName in
            guard let mapping = store.mapping(for: buttonName) else { return }
            ActionExecutor.shared.execute(mapping: mapping)
        }
        MouseTapService.shared.start()
    }

    // MARK: - Quit

    @objc private func quitApp() {
        MouseDeviceMonitor.shared.stop()
        MouseTapService.shared.stop()
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
