# MouseDriver

A powerful macOS mouse driver application that allows users to customize mouse button behaviors, execute keyboard shortcuts, key sequences, and shell commands.

<img src="https://github.com/BrunoMa0429/MouseDriver-Mac/blob/main/MouseDriver/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png">

<img src="https://github.com/BrunoMa0429/MouseDriver-Mac/blob/main/doc/appui_snapshot.png">

## Features

- **Custom mouse button mapping**: Set different behaviors for different mouse buttons
- **Support for multiple action types**:
  - Execute shell commands
  - Simulate keyboard shortcuts (e.g., `cmd+shift+4`)
  - Simulate key sequences (e.g., `h,e,l,l,o` or `enter,tab`)
- **Device management**: Support multiple mouse devices, each with independent mappings
- **Background running**: Runs as a background agent application without a Dock icon
- **Status bar icon**: Quick access to the configuration interface via the status bar icon

## System Requirements

- macOS 13.0 or later
- Accessibility permissions (for listening to mouse buttons and executing keyboard operations)

## Installation

1. Download the latest release
2. Extract and drag `MouseDriver.app` to the Applications folder
3. On first run, the system will prompt for accessibility permissions
4. Enable MouseDriver in System Settings → Privacy & Security → Accessibility

## Usage

1. Click the mouse icon in the menu bar to open the configuration window
2. Select a connected mouse device
3. Click "Add Button Mapping" to add a new button mapping
4. Click the "Detect" button and press the mouse button to map
5. Select the action type (Command, Shortcut, or Key Sequence)
6. Enter the corresponding action value
7. Click "OK" to save the mapping

## Action Types

### Command
Execute shell commands, for example:
- `open /Applications/Safari.app` - Open Safari
- `osascript -e 'display notification "Hello World"'` - Show notification

### Shortcut
Simulate keyboard shortcuts, for example:
- `cmd+c` - Copy
- `cmd+shift+4` - Screenshot
- `ctrl+alt+delete` - Force quit

### Key Sequence
Simulate sequential keyboard presses, for example:
- `h,e,l,l,o` - Type "hello"
- `enter,tab` - Press Enter then Tab

## Project Structure

```
MouseDriver/
├── App/
│   ├── AppDelegate.swift
│   └── main.swift
├── Models/
│   ├── ButtonMapping.swift
│   └── MouseDevice.swift
├── Services/
│   ├── ActionExecutor.swift
│   ├── ConfigStore.swift
│   ├── KeyboardRecorder.swift
│   ├── MouseDeviceMonitor.swift
│   └── MouseTapService.swift
├── UI/
│   ├── CommandExamplesView.swift
│   ├── ContentView.swift
│   └── MappingEditView.swift
└── Resources/
    └── Assets.xcassets/
```

## Technical Implementation

- **Swift 5.9**: Using modern Swift syntax
- **Cocoa**: Using macOS native frameworks
- **IOKit**: For monitoring mouse devices
- **ApplicationServices**: For creating mouse event taps
- **SwiftUI**: For building the user interface

## Notes

- The application requires accessibility permissions to work properly
- When the application is running in the background, some warnings related to system input method services may appear in the console, which is normal and does not affect application functionality
- Please ensure to follow security best practices when using shell commands, avoiding execution of unknown or dangerous commands

## Contributing

Welcome to submit Issues and Pull Requests to improve this project!

## License

[MIT License](LICENSE)
