import Cocoa

NSApplication.shared.setActivationPolicy(.accessory)

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate

withExtendedLifetime(appDelegate) {
    NSApplication.shared.run()
}
