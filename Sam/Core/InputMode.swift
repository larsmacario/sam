import Foundation

/// Eingabemodus, umgeschaltet per fn+Option, sichtbar in der Pille.
enum InputMode: String, CaseIterable, Identifiable, Sendable {
    /// Sprache → Text, direkt ins aktive Feld einfügen. Kein KI-Aufruf, kein API-Key nötig.
    case dictation
    /// Sprache oder Text → KI-Aktion am Cursor oder Mehrturn-Dialog im Chat-Fenster.
    case ai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation: return "Diktat"
        case .ai: return "KI"
        }
    }

    /// SF-Symbol für die Pille/Menüleiste.
    var symbol: String {
        switch self {
        case .dictation: return "text.cursor"
        case .ai: return "sparkles"
        }
    }

    func toggled() -> InputMode {
        switch self {
        case .dictation: return .ai
        case .ai: return .dictation
        }
    }
}
