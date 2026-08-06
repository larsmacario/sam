import AppKit
import ApplicationServices
import Carbon
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "ContextProvider")

private let copySentinel = "⟦SAM_NO_SELECTION⟧"

private let editableTextRoles: Set<String> = [
    "AXTextField",
    "AXTextArea",
    "AXSearchField",
    "AXComboBox"
]

struct SessionContext: Sendable {
    let frontmostAppName: String?
    let selectedText: String?
    /// Cursor in bearbeitbarem Textfeld (Einfügen per Paste möglich).
    let hasEditableInsertionPoint: Bool
}

/// Liefert Kontext der aktiven App und markierten Text via Accessibility API.
final class ContextProvider: Sendable {
    static let shared = ContextProvider()

    private init() {}

    @MainActor
    func capture() async -> SessionContext {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let hasEditableInsertionPoint = detectEditableInsertionPoint()
        let selectedText = await readSelectedText(preferCopyFirst: !hasEditableInsertionPoint)
        logger.debug(
            "Kontext: App=\(appName ?? "nil", privacy: .public), Auswahl=\(selectedText?.count ?? 0) Zeichen, editierbar=\(hasEditableInsertionPoint, privacy: .public)"
        )
        return SessionContext(
            frontmostAppName: appName,
            selectedText: selectedText,
            hasEditableInsertionPoint: hasEditableInsertionPoint
        )
    }

    @MainActor
    private func readSelectedText(preferCopyFirst: Bool) async -> String? {
        guard AXIsProcessTrusted() else { return nil }

        if preferCopyFirst {
            if let copied = await readSelectedTextViaCopy(), !copied.isEmpty { return copied }
            if let axText = readSelectedTextViaAccessibility(), !axText.isEmpty { return axText }
        } else {
            if let axText = readSelectedTextViaAccessibility(), !axText.isEmpty { return axText }
            if let copied = await readSelectedTextViaCopy(), !copied.isEmpty { return copied }
        }
        return nil
    }

    private func detectEditableInsertionPoint() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let element = focusedElement() else { return false }
        guard let role = axStringAttribute(element, kAXRoleAttribute as CFString),
              editableTextRoles.contains(role) else {
            return false
        }
        if let readOnly = axBoolAttribute(element, "AXReadOnly" as CFString), readOnly {
            return false
        }
        return true
    }

    private func focusedElement() -> AXUIElement? {
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
        return (element as! AXUIElement)
    }

    private func readSelectedTextViaAccessibility() -> String? {
        guard let element = focusedElement() else { return nil }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    /// Fallback: Cmd+C simulieren und Pasteboard auslesen (funktioniert in Mail, Browser, Electron).
    @MainActor
    private func readSelectedTextViaCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(copySentinel, forType: .string)

        guard simulateCopy() else {
            restorePasteboard(pasteboard, items: savedItems)
            return nil
        }

        try? await Task.sleep(nanoseconds: 150_000_000)

        let copied = pasteboard.string(forType: .string)
        restorePasteboard(pasteboard, items: savedItems)

        guard let copied, copied != copySentinel, !copied.isEmpty else {
            logger.debug("Copy-Fallback: keine Auswahl erkannt")
            return nil
        }

        logger.debug("Copy-Fallback: Auswahl=\(copied.count, privacy: .public) Zeichen")
        return copied
    }

    private func axStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func axBoolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private func simulateCopy() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
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
