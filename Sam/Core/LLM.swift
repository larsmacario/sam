import Foundation

// MARK: - Provider & Modelle

/// Unterstützte KI-Anbieter. Erweiterbar ohne Änderung der Pipeline.
enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case claude
    case openai
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini (Google)"
        }
    }

    /// Hinweis-URL zum Erstellen eines API-Keys (für die UI).
    var consoleURL: String {
        switch self {
        case .claude: return "https://console.anthropic.com/settings/keys"
        case .openai: return "https://platform.openai.com/api-keys"
        case .gemini: return "https://aistudio.google.com/app/apikey"
        }
    }

    var models: [LLMModel] {
        switch self {
        case .claude:
            return [
                LLMModel(id: "claude-haiku-4-5", displayName: "Haiku (schnell)", provider: .claude),
                LLMModel(id: "claude-sonnet-4-6", displayName: "Sonnet (empfohlen)", provider: .claude),
                LLMModel(id: "claude-opus-4-6", displayName: "Opus (beste Qualität)", provider: .claude)
            ]
        case .openai:
            return [
                LLMModel(id: "gpt-5-mini", displayName: "GPT-5 mini (schnell)", provider: .openai),
                LLMModel(id: "gpt-5", displayName: "GPT-5 (empfohlen)", provider: .openai)
            ]
        case .gemini:
            return [
                LLMModel(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash (schnell)", provider: .gemini),
                LLMModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro (beste Qualität)", provider: .gemini)
            ]
        }
    }

    var defaultModel: LLMModel {
        switch self {
        case .claude: return models[1] // Sonnet
        case .openai: return models[1] // GPT-4o
        case .gemini: return models[0] // Flash
        }
    }

    func model(forID id: String) -> LLMModel {
        models.first(where: { $0.id == id }) ?? defaultModel
    }
}

/// Ein konkretes Modell eines Providers.
struct LLMModel: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let provider: LLMProvider
}

// MARK: - Chat-Nachrichten (Mehrturn-Dialog)

enum SamChatRole: String, Sendable {
    case user
    case assistant

    var apiRole: String {
        switch self {
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
}

struct SamChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: SamChatRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: SamChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Ausgabe-Aktion (Diktat-Einfügen)

enum LLMOutputAction: Sendable {
    case insertText(String)
    case showAnswer(String)
}

// MARK: - Fehler

enum LLMError: LocalizedError {
    case notConfigured
    case invalidResponse
    case apiError(status: Int, message: String)
    case noActionOutput
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Kein API-Key für den gewählten Anbieter konfiguriert. Bitte in den Einstellungen hinterlegen."
        case .invalidResponse:
            return "Ungültige Antwort vom KI-Anbieter."
        case .apiError(let status, let message):
            return "API-Fehler (\(status)): \(message)"
        case .noActionOutput:
            return "Der KI-Anbieter hat keinen Text zum Einfügen geliefert."
        case .network(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - Gemeinsames Protokoll für alle Clients

/// Abstraktion über alle KI-Anbieter. Pipeline arbeitet nur gegen dieses Protokoll.
protocol LLMProviding: Sendable {
    /// Einfacher Verbindungstest.
    func testConnection(modelID: String) async throws -> String

    /// KI-Modus: Ein-Turn-Aktion am Cursor, Ergebnis als einzufügender Text.
    func processAction(
        transcript: String,
        context: SessionContext,
        modelID: String
    ) async throws -> String

    /// Mehrturn-Dialog im KI-Modus.
    func sendChat(
        messages: [SamChatMessage],
        initialContext: SessionContext?,
        modelID: String
    ) async throws -> String
}

// MARK: - Geteilte Kontext-Hilfen

enum SamTools {
    static let insertTextName = "insert_text"
    static let insertTextDescription = "Fertigen Text ins aktive Textfeld am Cursor einfügen."
    static let textArgName = "text"

    static func actionSystemPrompt(
        assistantName: String = "SAM",
        userName: String = "Der Nutzer",
        properNames: [ProperNameEntry] = []
    ) -> String {
        var prompt = """
        Du bist \(assistantName), ein persönlicher Voice-Assistent auf macOS.
        \(userName) gibt dir eine gesprochene ANWEISUNG. Führe genau diese Anweisung aus \
        und liefere das fertige Ergebnis als einzufügenden Text.

        Regeln:
        1. Das Transkript ist die Anweisung – wiederhole oder zitiere sie nicht im Ergebnis.
        2. Wenn markierter Text mitgeliefert wird, bearbeite ausschließlich diesen Inhalt \
        (z. B. zusammenfassen, übersetzen, umformulieren, korrigieren). Das gilt auch für \
        markierten Fließtext ohne Textfeld (Webseite, PDF, Mail-Lesebereich).
        3. Ohne markierten Text erzeugst du neuen Inhalt am Cursor (z. B. E-Mail schreiben, \
        Text verfassen, Antwort formulieren).
        4. Liefere ausschließlich über das Tool \(insertTextName) – nur der fertige Text. \
        Keine Erklärungen, keine Meta-Kommentare, kein Markdown, keine Anführungszeichen drumherum.
        5. Sprache: Wenn die Anweisung eine Zielsprache nennt, verwende diese. Sonst behalte \
        die Sprache des markierten Textes bei; ohne Markierung antworte auf Deutsch, sofern \
        die Anweisung nichts anderes verlangt.

        Beispiele:
        - Anweisung „Schreibe mir folgende Mail …" → fertige E-Mail als Ergebnis.
        - Anweisung „Fasse den Text zusammen" + markierter Text → Kurzfassung des markierten Textes.
        - Anweisung „Übersetze ins Englische" + markierter Fließtext (Safari/PDF) → englische Übersetzung, nur der übersetzte Text.
        """
        if let block = properNamesPromptBlock(from: properNames) {
            prompt += "\n\n\(block)"
        }
        return prompt
    }

    @MainActor
    static func resolvedActionSystemPrompt() -> String {
        let settings = SettingsStore.shared
        return actionSystemPrompt(
            assistantName: settings.assistantDisplayName,
            userName: settings.userDisplayName,
            properNames: settings.validProperNames
        )
    }

    static func properNamesPromptBlock(from entries: [ProperNameEntry]) -> String? {
        let lines = entries
            .filter(\.isValid)
            .map { "- \($0.trimmedLabel): \($0.trimmedValue)" }
        guard !lines.isEmpty else { return nil }
        return "Bekannte Eigennamen:\n" + lines.joined(separator: "\n")
    }

    /// Baut den User-Inhalt inkl. Kontext (App, markierter Text).
    static func userContent(transcript: String, context: SessionContext) -> String {
        var content = "Anweisung (gesprochen):\n\(transcript)"
        if let appName = context.frontmostAppName {
            content += "\n\nAktive App: \(appName)"
        }
        if let selected = context.selectedText, !selected.isEmpty {
            content += "\n\nMarkierter Text (ausschließlich diesen Inhalt bearbeiten):\n\(selected)"
        } else {
            content += "\n\nMarkierter Text: (keiner – neuen Inhalt am Cursor erzeugen)"
        }
        return content
    }
}

/// KI-Modus: konversationeller Prompt und API-Payload für Mehrturn-Dialog.
enum SamChat {
    static func systemPrompt(
        assistantName: String = "SAM",
        userName: String = "Der Nutzer",
        properNames: [ProperNameEntry] = []
    ) -> String {
        var prompt = """
        Du bist \(assistantName), ein persönlicher Voice-Assistent auf macOS.
        \(userName) führt einen Dialog mit dir. Antworte klar, prägnant und auf Deutsch,
        sofern \(userName) nicht ausdrücklich eine andere Sprache wünscht.
        """
        if let block = SamTools.properNamesPromptBlock(from: properNames) {
            prompt += "\n\n\(block)"
        }
        return prompt
    }

    @MainActor
    static func resolvedSystemPrompt() -> String {
        let settings = SettingsStore.shared
        return systemPrompt(
            assistantName: settings.assistantDisplayName,
            userName: settings.userDisplayName,
            properNames: settings.validProperNames
        )
    }

    /// Baut die Nachrichtenliste für die API; Kontext nur bei der ersten User-Nachricht.
    static func apiMessages(from messages: [SamChatMessage], initialContext: SessionContext?) -> [(role: String, content: String)] {
        messages.enumerated().map { index, message in
            if index == 0, message.role == .user, let context = initialContext {
                return (message.role.apiRole, SamTools.userContent(transcript: message.content, context: context))
            }
            return (message.role.apiRole, message.content)
        }
    }
}

// MARK: - Factory

/// Erzeugt den passenden Client für einen Provider.
enum LLMClientFactory {
    static func make(for provider: LLMProvider) -> any LLMProviding {
        let auth = APIKeyAuthProvider(provider: provider)
        switch provider {
        case .claude: return ClaudeClient(authProvider: auth)
        case .openai: return OpenAIClient(authProvider: auth)
        case .gemini: return GeminiClient(authProvider: auth)
        }
    }
}
