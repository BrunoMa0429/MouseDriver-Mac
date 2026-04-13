import SwiftUI

struct CommandExample: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let description: String
}

struct CommandCategory: Identifiable {
    let id = UUID()
    let title: String
    let examples: [CommandExample]
}

let commandCategories: [CommandCategory] = [
    CommandCategory(title: "System Control", examples: [
        CommandExample(name: "Lock Screen",
                       command: "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend",
                       description: "Immediately lock the screen and return to the login window"),
        CommandExample(name: "Sleep",
                       command: "pmset sleepnow",
                       description: "Put the Mac to sleep immediately"),
        CommandExample(name: "Turn Off Display",
                       command: "pmset displaysleepnow",
                       description: "Turn off the display only; system keeps running"),
        CommandExample(name: "Restart",
                       command: "osascript -e 'tell app \"System Events\" to restart'",
                       description: "Restart the Mac (prompts to save open documents)"),
        CommandExample(name: "Shut Down",
                       command: "osascript -e 'tell app \"System Events\" to shut down'",
                       description: "Shut down the Mac (prompts to save open documents)"),
    ]),
    CommandCategory(title: "Volume & Media", examples: [
        CommandExample(name: "Toggle Mute",
                       command: "osascript -e 'set volume output muted not (output muted of (get volume settings))'",
                       description: "Toggle system mute on/off"),
        CommandExample(name: "Volume +10%",
                       command: "osascript -e 'set volume output volume ((output volume of (get volume settings)) + 10)'",
                       description: "Increase system volume by 10%"),
        CommandExample(name: "Volume -10%",
                       command: "osascript -e 'set volume output volume ((output volume of (get volume settings)) - 10)'",
                       description: "Decrease system volume by 10%"),
        CommandExample(name: "Play / Pause",
                       command: "osascript -e 'tell application \"System Events\" to key code 16 using {}'",
                       description: "Simulate the media Play/Pause key (F8)"),
        CommandExample(name: "Next Track",
                       command: "osascript -e 'tell application \"System Events\" to key code 17 using {}'",
                       description: "Skip to the next track (F9)"),
        CommandExample(name: "Previous Track",
                       command: "osascript -e 'tell application \"System Events\" to key code 18 using {}'",
                       description: "Go back to the previous track (F7)"),
    ]),
    CommandCategory(title: "Applications", examples: [
        CommandExample(name: "Open Finder",
                       command: "open -a Finder",
                       description: "Open the Finder file manager"),
        CommandExample(name: "Open Terminal",
                       command: "open -a Terminal",
                       description: "Open the system Terminal"),
        CommandExample(name: "Open Safari",
                       command: "open -a Safari",
                       description: "Open Safari browser"),
        CommandExample(name: "Open Chrome",
                       command: "open -a 'Google Chrome'",
                       description: "Open Google Chrome browser"),
        CommandExample(name: "Open System Settings",
                       command: "open -a 'System Settings'",
                       description: "Open System Settings (macOS 13+)"),
        CommandExample(name: "Open System Preferences",
                       command: "open -a 'System Preferences'",
                       description: "Open System Preferences (macOS 12 and earlier)"),
        CommandExample(name: "Open Calculator",
                       command: "open -a Calculator",
                       description: "Open the system Calculator"),
        CommandExample(name: "Force Quit Frontmost App",
                       command: "osascript -e 'tell application \"System Events\" to key code 53 using {command down, option down, escape down}'",
                       description: "Simulate Cmd+Option+Esc to open the Force Quit window"),
    ]),
    CommandCategory(title: "Windows & Desktop", examples: [
        CommandExample(name: "Show Desktop",
                       command: "osascript -e 'tell application \"System Events\" to key code 103 using {}'",
                       description: "Show/hide all windows to reveal the desktop (Mission Control Show Desktop)"),
        CommandExample(name: "Mission Control",
                       command: "open -a 'Mission Control'",
                       description: "Open Mission Control to see all open windows"),
        CommandExample(name: "Screenshot to Clipboard",
                       command: "screencapture -c -s",
                       description: "Drag to select a region and copy it to the clipboard"),
        CommandExample(name: "Screenshot to Desktop",
                       command: "screencapture -s ~/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png",
                       description: "Drag to select a region and save with a timestamp to the Desktop"),
        CommandExample(name: "Full-screen Screenshot",
                       command: "screencapture ~/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png",
                       description: "Capture the full screen and save to the Desktop"),
    ]),
    CommandCategory(title: "Network", examples: [
        CommandExample(name: "Open URL",
                       command: "open 'https://www.example.com'",
                       description: "Open a URL in the default browser — replace with the actual URL"),
        CommandExample(name: "Enable Wi-Fi",
                       command: "networksetup -setairportpower en0 on",
                       description: "Turn Wi-Fi on (en0 is typically the wireless interface)"),
        CommandExample(name: "Disable Wi-Fi",
                       command: "networksetup -setairportpower en0 off",
                       description: "Turn Wi-Fi off"),
    ]),
    CommandCategory(title: "Notifications & Alerts", examples: [
        CommandExample(name: "Send Notification",
                       command: "osascript -e 'display notification \"Hello from MouseDriver\" with title \"MouseDriver\"'",
                       description: "Display a notification in Notification Center — customise the title and body"),
        CommandExample(name: "Text-to-Speech",
                       command: "say 'Hello, world'",
                       description: "Speak text aloud using the system TTS engine — change the text as needed"),
        CommandExample(name: "Play System Sound",
                       command: "afplay /System/Library/Sounds/Ping.aiff",
                       description: "Play a built-in system sound file"),
    ]),
]

struct CommandExamplesView: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var filteredCategories: [CommandCategory] {
        if searchText.isEmpty { return commandCategories }
        return commandCategories.compactMap { cat in
            let filtered = cat.examples.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.command.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : CommandCategory(title: cat.title, examples: filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shell Command Examples")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search commands…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(filteredCategories) { category in
                        Section {
                            ForEach(category.examples) { example in
                                ExampleRow(example: example) {
                                    onSelect(example.command)
                                    dismiss()
                                }
                                if example.id != category.examples.last?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        } header: {
                            Text(category.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.windowBackgroundColor))
                        }
                    }
                }
            }
        }
        .frame(width: 560, height: 480)
    }
}

private struct ExampleRow: View {
    let example: CommandExample
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(example.name)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(example.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(example.command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(isHovered ? .accentColor : .secondary)
                    .imageScale(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
