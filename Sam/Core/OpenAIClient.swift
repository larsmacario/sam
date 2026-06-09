import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "OpenAIClient")

/// OpenAI Chat Completions API mit Function Calling für Intent-Routing.
final class OpenAIClient: LLMProviding {
    private let authProvider: AuthProviding
    private let session: URLSession

    init(authProvider: AuthProviding, session: URLSession = .shared) {
        self.authProvider = authProvider
        self.session = session
    }

    func testConnection(modelID: String) async throws -> String {
        let body = ChatRequest(
            model: modelID,
            messages: [
                ChatMessage(role: "user", content: "Antworte nur mit: Verbindung OK")
            ],
            max_completion_tokens: 64,
            tools: nil,
            tool_choice: nil
        )
        let response: ChatResponse = try await send(body)
        return response.choices.first?.message.content ?? "Verbindung OK"
    }

    func processTranscript(
        transcript: String,
        context: SessionContext,
        modelID: String
    ) async throws -> LLMOutputAction {
        let body = ChatRequest(
            model: modelID,
            messages: [
                ChatMessage(role: "system", content: SamTools.systemPrompt),
                ChatMessage(role: "user", content: SamTools.userContent(transcript: transcript, context: context))
            ],
            max_completion_tokens: 4096,
            tools: [
                makeTool(name: SamTools.insertTextName, description: SamTools.insertTextDescription, argDescription: "Der einzufügende Text"),
                makeTool(name: SamTools.showAnswerName, description: SamTools.showAnswerDescription, argDescription: "Die anzuzeigende Antwort")
            ],
            tool_choice: .string("required")
        )

        let response: ChatResponse = try await send(body)

        if let call = response.choices.first?.message.tool_calls?.first {
            let text = decodeArgumentText(call.function.arguments)
            if let text, let action = SamTools.action(forToolName: call.function.name, text: text) {
                return action
            }
        }

        if let content = response.choices.first?.message.content, !content.isEmpty {
            return .showAnswer(content)
        }

        throw LLMError.noToolUse
    }

    private func makeTool(name: String, description: String, argDescription: String) -> Tool {
        Tool(function: FunctionDef(
            name: name,
            description: description,
            parameters: ParametersSchema(
                properties: [SamTools.textArgName: PropertySchema(type: "string", description: argDescription)],
                required: [SamTools.textArgName]
            )
        ))
    }

    private func decodeArgumentText(_ arguments: String) -> String? {
        guard let data = arguments.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return nil
        }
        return parsed[SamTools.textArgName]?.stringValue
    }

    private func send<T: Decodable>(_ body: ChatRequest) async throws -> T {
        guard await authProvider.isConfigured else {
            throw LLMError.notConfigured
        }
        let apiKey = try await authProvider.apiKey()

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            let message = (try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unbekannter Fehler"
            logger.error("API error \(http.statusCode): \(message, privacy: .public)")
            throw LLMError.apiError(status: http.statusCode, message: message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API-Modelle

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let max_completion_tokens: Int
    let tools: [Tool]?
    let tool_choice: ToolChoice?
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct Tool: Encodable {
    let type = "function"
    let function: FunctionDef
}

private struct FunctionDef: Encodable {
    let name: String
    let description: String
    let parameters: ParametersSchema
}

private struct ParametersSchema: Encodable {
    let type = "object"
    let properties: [String: PropertySchema]
    let required: [String]
}

private struct PropertySchema: Encodable {
    let type: String
    let description: String
}

private enum ToolChoice: Encodable {
    case string(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        }
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
        let tool_calls: [ToolCall]?
    }

    struct ToolCall: Decodable {
        let function: FunctionCall
    }

    struct FunctionCall: Decodable {
        let name: String
        let arguments: String
    }
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
