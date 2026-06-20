import Foundation

/// Eingabemodus, umgeschaltet per fn+Option, sichtbar in der Pille.
enum InputMode: String, CaseIterable, Identifiable, Sendable {
    /// Sprache → Text, direkt ins aktive Feld einfügen. Kein KI-Aufruf, kein API-Key nötig.
    case dictation
    /// Sprache → KI-Aktion am Cursor (übersetzen, schreiben, umformulieren).
    case ai
    /// Sprache oder Text → Mehrturn-Dialog im Chat-Fenster.
    case chat
    /// fn+⌘ startet/stoppt Meeting-Aufnahme mit Transkript und Zusammenfassung.
    case meeting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation: return "Diktat"
        case .ai: return "KI"
        case .chat: return "Chat"
        case .meeting: return "Meeting"
        }
    }

    /// SF-Symbol für die Pille/Menüleiste.
    var symbol: String {
        switch self {
        case .dictation: return "text.cursor"
        case .ai: return "sparkles"
        case .chat: return "bubble.left.and.bubble.right"
        case .meeting: return "person.3.fill"
        }
    }

    func toggled() -> InputMode {
        switch self {
        case .dictation: return .ai
        case .ai: return .chat
        case .chat: return .meeting
        case .meeting: return .dictation
        }
    }
}
