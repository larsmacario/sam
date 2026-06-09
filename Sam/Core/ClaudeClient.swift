import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "ClaudeClient")

/// Anthropic Messages API mit Tool-Use für Intent-Routing.
final class ClaudeClient: LLMProviding {
    private let authProvider: AuthProviding
    private let session: URLSession

    init(authProvider: AuthProviding, session: URLSession = .shared) {
        self.authProvider = authProvider
        self.session = session
    }

    func testConnection(modelID: String) async throws -> String {
        let body = MessagesRequest(
            model: modelID,
            max_tokens: 64,
            messages: [Message(role: "user", content: "Antworte nur mit: Verbindung OK")]
        )
        let response: MessagesResponse = try await send(body)
        return response.textContent ?? "Verbindung OK"
    }

    func processTranscript(
        transcript: String,
        context: SessionContext,
        modelID: String
    ) async throws -> LLMOutputAction {
        let systemPrompt = await MainActor.run { SamTools.resolvedSystemPrompt() }
        let body = MessagesRequest(
            model: modelID,
            max_tokens: 4096,
            system: systemPrompt,
            tools: [
                ToolDefinition(
                    name: SamTools.insertTextName,
                    description: SamTools.insertTextDescription,
                    input_schema: ToolSchema(
                        properties: [SamTools.textArgName: ToolProperty(type: "string", description: "Der einzufügende Text")],
                        required: [SamTools.textArgName]
                    )
                ),
                ToolDefinition(
                    name: SamTools.showAnswerName,
                    description: SamTools.showAnswerDescription,
                    input_schema: ToolSchema(
                        properties: [SamTools.textArgName: ToolProperty(type: "string", description: "Die anzuzeigende Antwort")],
                        required: [SamTools.textArgName]
                    )
                )
            ],
            tool_choice: ToolChoice(type: "any"),
            messages: [Message(role: "user", content: SamTools.userContent(transcript: transcript, context: context))]
        )

        let response: MessagesResponse = try await send(body)

        for block in response.content where block.type == "tool_use" {
            if let name = block.name,
               let text = block.input?[SamTools.textArgName]?.stringValue,
               let action = SamTools.action(forToolName: name, text: text) {
                return action
            }
        }

        if let text = response.textContent, !text.isEmpty {
            return .showAnswer(text)
        }

        throw LLMError.noToolUse
    }

    func sendChat(
        messages: [SamChatMessage],
        initialContext: SessionContext?,
        modelID: String
    ) async throws -> String {
        let payload = SamChat.apiMessages(from: messages, initialContext: initialContext)
        let systemPrompt = await MainActor.run { SamChat.resolvedSystemPrompt() }
        let body = MessagesRequest(
            model: modelID,
            max_tokens: 4096,
            system: systemPrompt,
            tools: nil,
            tool_choice: nil,
            messages: payload.map { Message(role: $0.role, content: $0.content) }
        )

        let response: MessagesResponse = try await send(body)
        if let text = response.textContent, !text.isEmpty {
            return text
        }
        throw LLMError.invalidResponse
    }

    private func send<T: Decodable>(_ body: MessagesRequest) async throws -> T {
        guard await authProvider.isConfigured else {
            throw LLMError.notConfigured
        }

        let apiKey = try await authProvider.apiKey()

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LLMError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if http.statusCode != 200 {
            let message = (try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unbekannter Fehler"
            logger.error("API error \(http.statusCode): \(message, privacy: .public)")
            throw LLMError.apiError(status: http.statusCode, message: message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API-Modelle

private struct MessagesRequest: Encodable {
    let model: String
    let max_tokens: Int
    var system: String?
    var tools: [ToolDefinition]?
    var tool_choice: ToolChoice?
    let messages: [Message]
}

private struct Message: Encodable {
    let role: String
    let content: String
}

private struct ToolDefinition: Encodable {
    let name: String
    let description: String
    let input_schema: ToolSchema
}

private struct ToolSchema: Encodable {
    let type: String = "object"
    let properties: [String: ToolProperty]
    let required: [String]
}

private struct ToolProperty: Encodable {
    let type: String
    let description: String
}

private struct ToolChoice: Encodable {
    let type: String
}

private struct MessagesResponse: Decodable {
    let content: [ContentBlock]

    var textContent: String? {
        content.first(where: { $0.type == "text" })?.text
    }
}

private struct ContentBlock: Decodable {
    let type: String
    let text: String?
    let name: String?
    let input: [String: JSONValue]?
}

private struct AnthropicErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
