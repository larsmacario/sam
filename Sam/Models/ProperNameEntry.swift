import Foundation

/// Ein benutzerdefinierter Eigenname (Label + Wert), z. B. Assistentenname oder Firmenname.
struct ProperNameEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var value: String

    init(id: UUID = UUID(), label: String = "", value: String = "") {
        self.id = id
        self.label = label
        self.value = value
    }

    var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedLabel.isEmpty && !trimmedValue.isEmpty
    }
}

enum ProperNameLabel {
    static let assistantName = "Assistentenname"
    static let userName = "Dein Name"

    static let suggestions = [
        assistantName,
        userName,
        "Aussprache",
        "Firmenname"
    ]

    static func matches(_ label: String, _ expected: String) -> Bool {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(expected) == .orderedSame
    }
}
