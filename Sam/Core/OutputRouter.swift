import AppKit
import Carbon
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "OutputRouter")

enum OutputRouterError: LocalizedError {
    case accessibilityRequired
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "Accessibility-Berechtigung wird für das Einfügen benötigt."
        case .pasteFailed:
            return "Text konnte nicht eingefügt werden."
        }
    }
}

/// Leitet KI-Ausgabe entweder per Clipboard+Cmd+V ein oder zeigt sie im Overlay.
@MainActor
final class OutputRouter {
    static let shared = OutputRouter()

    private let overlay = OverlayWindowController.shared

    private init() {}

    func route(_ action: LLMOutputAction) async throws {
        switch action {
        case .insertText(let text):
            try await pasteText(text)
        case .showAnswer(let text):
            overlay.showAnswer(text)
        }
    }

    func pasteText(_ text: String) async throws {
        try await insertText(text)
    }

    private func insertText(_ text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw OutputRouterError.accessibilityRequired
        }

        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let pasted = simulatePaste()
        logger.info("Einfügen simuliert: \(pasted, privacy: .public)")

        // Clipboard nach kurzer Verzögerung wiederherstellen
        try await Task.sleep(nanoseconds: 150_000_000)
        restorePasteboard(pasteboard, items: savedItems)

        if !pasted {
            // Fallback: Antwort im Fenster zeigen
            overlay.showAnswer(text)
        }
    }

    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        return keyDown != nil && keyUp != nil
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]]? {
        guard let items = pasteboard.pasteboardItems else { return nil }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        items: [[NSPasteboard.PasteboardType: Data]]?
    ) {
        pasteboard.clearContents()
        guard let items, !items.isEmpty else { return }

        let newItems = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(newItems)
    }
}
