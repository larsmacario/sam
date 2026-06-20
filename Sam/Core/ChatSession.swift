import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "ChatSession")

/// Verwaltet Mehrturn-Chat-Historie und KI-Aufrufe im Chat-Modus.
@MainActor
final class ChatSessionController: ObservableObject {
    static let shared = ChatSessionController()

    @Published private(set) var messages: [SamChatMessage] = []
    @Published private(set) var isProcessing = false

    /// Kontext der ersten Nachricht (nur für API-Payload).
    private var initialContext: SessionContext?

    private let settings = SettingsStore.shared
    private let overlay = OverlayWindowController.shared

    var hasActiveSession: Bool { !messages.isEmpty }

    private init() {}

    func reset() {
        messages = []
        initialContext = nil
        isProcessing = false
        overlay.hideChat()
    }

    /// Zeigt ein KI-Modus-Ergebnis im Chat (markierter Text ohne Textfeld) – ohne zweiten LLM-Aufruf.
    func presentAIResult(instruction: String, result: String, context: SessionContext?) {
        messages = []
        initialContext = context
        isProcessing = false

        var userContent = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selected = context?.selectedText, !selected.isEmpty {
            userContent += "\n\n(Markierter Text, \(selected.count) Zeichen)"
        }

        messages.append(SamChatMessage(role: .user, content: userContent))
        messages.append(SamChatMessage(role: .assistant, content: result))
        overlay.showChat()
        logger.info("KI-Ergebnis im Chat: Länge=\(result.count)")
    }

    /// Sendet eine User-Nachricht (Sprache oder Text) und holt die Assistant-Antwort.
    func send(text: String, context: SessionContext?) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isProcessing else { return }
        guard settings.isActiveProviderConfigured else {
            throw LLMError.notConfigured
        }

        if messages.isEmpty {
            initialContext = context
        }

        messages.append(SamChatMessage(role: .user, content: trimmed))
        overlay.showChat()
        isProcessing = true

        defer { isProcessing = false }

        do {
            let client = LLMClientFactory.make(for: settings.selectedProvider)
            let reply = try await client.sendChat(
                messages: messages,
                initialContext: initialContext,
                modelID: settings.currentModelID
            )
            messages.append(SamChatMessage(role: .assistant, content: reply))
            logger.info("Chat-Antwort: Länge=\(reply.count)")
        } catch {
            logger.error("Chat-Fehler: \(error.localizedDescription, privacy: .public)")
            messages.append(SamChatMessage(role: .assistant, content: "Fehler: \(error.localizedDescription)"))
            throw error
        }
    }
}
