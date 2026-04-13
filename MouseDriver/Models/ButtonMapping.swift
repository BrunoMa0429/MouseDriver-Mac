import Foundation

enum ActionType: String, Codable, CaseIterable, Identifiable {
    case command     = "command"
    case shortcut    = "shortcut"
    case keySequence = "key_sequence"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .command:     return "Shell Command"
        case .shortcut:    return "Shortcut"
        case .keySequence: return "Key Sequence"
        }
    }

    var hint: String {
        switch self {
        case .command:
            return "e.g.  open -a Safari  /  say hello  /  open /Applications/Calculator.app"
        case .shortcut:
            return "e.g.  cmd+c  /  cmd+shift+4  /  ctrl+alt+t"
        case .keySequence:
            return "e.g.  h,e,l,l,o  /  enter,tab   (comma-separated, fired in order)"
        }
    }
}

struct ButtonMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var button: String
    var actionType: ActionType
    var actionValue: String
    var note: String        // User-facing description of what this mapping does
    var enabled: Bool

    init(id: UUID = UUID(), button: String, actionType: ActionType, actionValue: String, note: String = "", enabled: Bool = true) {
        self.id = id
        self.button = button
        self.actionType = actionType
        self.actionValue = actionValue
        self.note = note
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case button
        case actionType  = "action_type"
        case actionValue = "action_value"
        case note
        case enabled
    }
}
