import SwiftUI

struct MappingEditView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) var dismiss

    var existing: ButtonMapping?

    @State private var button: String = ""
    @State private var actionType: ActionType = .command
    @State private var actionValue: String = ""
    @State private var note: String = ""
    @State private var enabled: Bool = true

    // Mouse capture state
    @State private var mouseCaptureState: MouseCaptureState = .idle
    @State private var mouseCountdown: Int = 3
    @State private var mouseCountdownTimer: Timer? = nil

    // Keyboard record state
    @State private var keyRecordState: KeyRecordState = .idle
    @State private var keyCountdownTimer: Timer? = nil
    @State private var keyCountdown: Int = 5

    // Command examples sheet
    @State private var showCommandExamples = false

    @FocusState private var focusedField: Bool

    enum MouseCaptureState {
        case idle, listening(Int), captured(String), timeout
    }

    enum KeyRecordState {
        case idle, recording(Int), recorded(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(existing == nil ? "Add Button Mapping" : "Edit Button Mapping")
                .font(.headline)
                .padding(.bottom, 16)

            Form {
                // ── Mouse button ──────────────────────────────────────
                Section {
                    HStack(spacing: 8) {
                        TextField("Press a mouse button to detect", text: $button)
                            .disabled(true)
                            .textFieldStyle(.roundedBorder)

                        Button(action: handleMouseCapture) {
                            switch mouseCaptureState {
                            case .idle:             Text("Detect")
                            case .listening(let n): Text("Waiting… \(n)s")
                            case .captured:         Text("Re-detect")
                            case .timeout:          Text("Re-detect")
                            }
                        }
                        .frame(width: 90)
                        .disabled({ if case .listening = mouseCaptureState { return true }; return false }())
                    }
                    mouseCaptureHintView
                } header: {
                    Text("Mouse Button")
                }

                // ── Action ────────────────────────────────────────────
                Section {
                    // Action value row
                    if actionType == .shortcut {
                        HStack(spacing: 8) {
                            TextField("e.g. cmd+shift+4", text: $actionValue)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor({ if case .recording = keyRecordState { return .orange } else { return .primary } }())
                                .focused($focusedField)
                                .onChange(of: actionValue) { _ in
                                    if case .recording = keyRecordState { stopKeyRecord(); keyRecordState = .idle }
                                }

                            Button(action: handleKeyRecord) {
                                switch keyRecordState {
                                case .idle:              Text("Record")
                                case .recording(let n):  Text("Recording… \(n)s")
                                case .recorded:          Text("Re-record")
                                }
                            }
                            .frame(width: 110)
                            .disabled({ if case .recording = keyRecordState { return true }; return false }())
                        }
                        keyRecordHintView
                    } else if actionType == .command {
                        HStack(spacing: 8) {
                            TextField("Command", text: $actionValue)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField)
                            Button("Examples") { showCommandExamples = true }
                                .frame(width: 70)
                        }
                    } else {
                        TextField("Action value", text: $actionValue)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField)
                    }

                    Text(actionType.hint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    HStack {
                        Text("Action")
                        Spacer()
                        Picker("", selection: $actionType) {
                            ForEach(ActionType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                        .onChange(of: actionType) { _ in
                            if actionType != .shortcut {
                                stopKeyRecord()
                                keyRecordState = .idle
                            }
                        }
                    }
                }

                // ── Description ───────────────────────────────────────
                Section {
                    TextField("Optional — describe what this mapping does", text: $note)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Description")
                }

                // ── Enabled ───────────────────────────────────────────
                Section {
                    Toggle("Enable this mapping", isOn: $enabled)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    cleanup()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("OK") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(button.isEmpty || actionValue.isEmpty)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 600)
        .frame(height: 550)
        .onAppear {
            loadExisting()
            // Defer to let SwiftUI finish layout, then clear focus
            DispatchQueue.main.async { focusedField = false }
        }
        .onDisappear { cleanup() }
        .sheet(isPresented: $showCommandExamples) {
            CommandExamplesView { command in
                actionValue = command
            }
        }
    }

    // MARK: - Mouse capture hints

    @ViewBuilder
    private var mouseCaptureHintView: some View {
        switch mouseCaptureState {
        case .idle:
            EmptyView()
        case .listening(let n):
            Text("Press the mouse button to identify within \(n)s")
                .font(.caption).foregroundColor(.orange)
        case .captured(let name):
            Text("Detected: \(name)")
                .font(.caption).foregroundColor(.green)
        case .timeout:
            Text("Timed out — no button detected. Please try again.")
                .font(.caption).foregroundColor(.orange)
        }
    }

    // MARK: - Keyboard record hints

    @ViewBuilder
    private var keyRecordHintView: some View {
        switch keyRecordState {
        case .idle:
            EmptyView()
        case .recording(let n):
            Text("Press the shortcut combination within \(n)s")
                .font(.caption).foregroundColor(.orange)
        case .recorded(let shortcut):
            Text("Recorded: \(shortcut)")
                .font(.caption).foregroundColor(.green)
        }
    }

    // MARK: - Mouse capture logic

    private func handleMouseCapture() {
        stopMouseCountdown()
        mouseCaptureState = .listening(3)
        mouseCountdown = 3

        MouseTapService.shared.startCapture(timeout: 3) { name in
            stopMouseCountdown()
            button = name
            mouseCaptureState = .captured(name)
        }

        mouseCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            mouseCountdown -= 1
            if mouseCountdown > 0 {
                mouseCaptureState = .listening(mouseCountdown)
            } else {
                stopMouseCountdown()
                if button.isEmpty { mouseCaptureState = .timeout }
            }
        }
    }

    private func stopMouseCountdown() {
        mouseCountdownTimer?.invalidate()
        mouseCountdownTimer = nil
    }

    // MARK: - Keyboard record logic

    private func handleKeyRecord() {
        stopKeyRecord()
        keyCountdown = 5
        keyRecordState = .recording(5)

        KeyboardRecorder.shared.startRecording { shortcut in
            stopKeyRecord()
            actionValue = shortcut
            keyRecordState = .recorded(shortcut)
        } onCancel: {
            stopKeyRecord()
            keyRecordState = .idle
        }

        keyCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            keyCountdown -= 1
            if keyCountdown > 0 {
                keyRecordState = .recording(keyCountdown)
            } else {
                stopKeyRecord()
                if case .recording = keyRecordState {
                    keyRecordState = .idle
                }
            }
        }
    }

    private func stopKeyRecord() {
        keyCountdownTimer?.invalidate()
        keyCountdownTimer = nil
        KeyboardRecorder.shared.stopRecording()
    }

    // MARK: - Cleanup / Save

    private func cleanup() {
        MouseTapService.shared.cancelCapture()
        stopMouseCountdown()
        stopKeyRecord()
    }

    private func loadExisting() {
        guard let m = existing else { return }
        button      = m.button
        actionType  = m.actionType
        actionValue = m.actionValue
        note        = m.note
        enabled     = m.enabled
        mouseCaptureState = .captured(m.button)
        if m.actionType == .shortcut, !m.actionValue.isEmpty {
            keyRecordState = .recorded(m.actionValue)
        }
    }

    private func commit() {
        let mapping = ButtonMapping(
            id:          existing?.id ?? UUID(),
            button:      button,
            actionType:  actionType,
            actionValue: actionValue,
            note:        note,
            enabled:     enabled
        )
        if existing != nil {
            store.update(mapping)
        } else {
            store.add(mapping)
        }
        dismiss()
    }
}
