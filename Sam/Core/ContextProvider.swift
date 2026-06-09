import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "ContextProvider")

struct SessionContext: Sendable {
    let frontmostAppName: String?
    let selectedText: String?
}

/// Liefert Kontext der aktiven App und markierten Text via Accessibility API.
final class ContextProvider: Sendable {
    static let shared = ContextProvider()

    private init() {}

    func capture() -> SessionContext {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let selectedText = readSelectedText()
        logger.debug("Kontext: App=\(appName ?? "nil", privacy: .public), Auswahl=\(selectedText?.count ?? 0) Zeichen")
        return SessionContext(frontmostAppName: appName, selectedText: selectedText)
    }

    private func readSelectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            return nil
        }
        return text
    }
}
