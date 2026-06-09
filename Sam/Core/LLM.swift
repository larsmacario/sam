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

// MARK: - Ausgabe-Aktion (Intent-Routing, provider-unabhängig)

enum LLMOutputAction: Sendable {
    case insertText(String)
    case showAnswer(String)
}

// MARK: - Fehler

enum LLMError: LocalizedError {
    case notConfigured
    case invalidResponse
    case apiError(status: Int, message: String)
    case noToolUse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Kein API-Key für den gewählten Anbieter konfiguriert. Bitte in den Einstellungen hinterlegen."
        case .invalidResponse:
            return "Ungültige Antwort vom KI-Anbieter."
        case .apiError(let status, let message):
            return "API-Fehler (\(status)): \(message)"
        case .noToolUse:
            return "Der KI-Anbieter hat keine Ausgabe-Aktion gewählt."
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

    /// Verarbeitet Transkript + Kontext und entscheidet via Tool-Use über die Ausgabe.
    func processTranscript(
        transcript: String,
        context: SessionContext,
        modelID: String
    ) async throws -> LLMOutputAction

    /// Mehrturn-Chat ohne Tool-Use (Chat-Modus).
    func sendChat(
        messages: [SamChatMessage],
        initialContext: SessionContext?,
        modelID: String
    ) async throws -> String
}

// MARK: - Geteilte Prompt-/Tool-Definitionen

/// SAMs logische Tools + System-Prompt, von allen Providern wiederverwendet.
/// Jeder Client übersetzt diese in sein providerspezifisches Schema.
enum SamTools {
    static let insertTextName = "insert_text"
    static let insertTextDescription = "Transformierten Text ins aktive Textfeld einfügen."
    static let showAnswerName = "show_answer"
    static let showAnswerDescription = "Antwort im schwebenden Fenster anzeigen."
    static let textArgName = "text"

    static func systemPrompt(
        assistantName: String = "SAM",
        userName: String = "Der Nutzer",
        properNames: [ProperNameEntry] = []
    ) -> String {
        var prompt = """
        Du bist \(assistantName), ein persönlicher Voice-Assistent auf macOS.
        \(userName) hat gesprochen und du erhältst das Transkript sowie optional Kontext.

        Entscheide anhand der Nutzerabsicht:
        - \(insertTextName): Wenn \(userName) Text umschreiben, übersetzen, korrigieren, formatieren \
        oder in ein Textfeld einfügen möchte. Beispiele: "Übersetze das", "Mache das formeller", \
        "Korrigiere den Text".
        - \(showAnswerName): Wenn \(userName) eine Frage stellt oder eine Erklärung/Antwort erwartet, \
        die nicht direkt eingefügt werden soll. Beispiele: "Was ist X?", "Erkläre mir Y".

        Wähle genau ein Tool und liefere den fertigen Text darin.
        """
        if let block = properNamesPromptBlock(from: properNames) {
            prompt += "\n\n\(block)"
        }
        return prompt
    }

    static func properNamesPromptBlock(from entries: [ProperNameEntry]) -> String? {
        let lines = entries
            .filter(\.isValid)
            .map { "- \($0.trimmedLabel): \($0.trimmedValue)" }
        guard !lines.isEmpty else { return nil }
        return "Bekannte Eigennamen:\n" + lines.joined(separator: "\n")
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

    /// Baut den User-Inhalt inkl. Kontext (App, markierter Text).
    static func userContent(transcript: String, context: SessionContext) -> String {
        var content = "Transkript: \(transcript)"
        if let appName = context.frontmostAppName {
            content += "\n\nAktive App: \(appName)"
        }
        if let selected = context.selectedText, !selected.isEmpty {
            content += "\n\nMarkierter Text:\n\(selected)"
        }
        return content
    }

    /// Normalisiert einen Tool-Call-Namen + Text zu einer Ausgabe-Aktion.
    static func action(forToolName name: String, text: String) -> LLMOutputAction? {
        switch name {
        case insertTextName: return .insertText(text)
        case showAnswerName: return .showAnswer(text)
        default: return nil
        }
    }
}

/// Chat-Modus: konversationeller Prompt und API-Payload.
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
