import Foundation

/// Eingabemodus, umgeschaltet per fn+Option, sichtbar in der Pille.
enum InputMode: String, CaseIterable, Identifiable, Sendable {
    /// Sprache → Text, direkt ins aktive Feld einfügen. Kein KI-Aufruf, kein API-Key nötig.
    case dictation
    /// Sprache → KI → Antwort (KI entscheidet einfügen vs. Fenster).
    case ai
    /// Sprache oder Text → Mehrturn-Dialog im Chat-Fenster.
    case chat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation: return "Diktat"
        case .ai: return "KI"
        case .chat: return "Chat"
        }
    }

    /// SF-Symbol für die Pille/Menüleiste.
    var symbol: String {
        switch self {
        case .dictation: return "text.cursor"
        case .ai: return "sparkles"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }

    func toggled() -> InputMode {
        switch self {
        case .dictation: return .ai
        case .ai: return .chat
        case .chat: return .dictation
        }
    }
}
