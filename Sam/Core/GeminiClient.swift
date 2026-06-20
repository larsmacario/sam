import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "GeminiClient")

/// Google Gemini generateContent API für KI-Aktionen und Mehrturn-Chat.
final class GeminiClient: LLMProviding {
    private let authProvider: AuthProviding
    private let session: URLSession

    init(authProvider: AuthProviding, session: URLSession = .shared) {
        self.authProvider = authProvider
        self.session = session
    }

    func testConnection(modelID: String) async throws -> String {
        let body = GenerateRequest(
            system_instruction: nil,
            contents: [Content(role: "user", parts: [Part(text: "Antworte nur mit: Verbindung OK", functionCall: nil)])],
            tools: nil,
            tool_config: nil
        )
        let response: GenerateResponse = try await send(body, modelID: modelID)
        return response.firstText ?? "Verbindung OK"
    }

    func processAction(
        transcript: String,
        context: SessionContext,
        modelID: String
    ) async throws -> String {
        let systemPrompt = await MainActor.run { SamTools.resolvedActionSystemPrompt() }
        let body = GenerateRequest(
            system_instruction: Content(role: nil, parts: [Part(text: systemPrompt, functionCall: nil)]),
            contents: [Content(role: "user", parts: [Part(text: SamTools.userContent(transcript: transcript, context: context), functionCall: nil)])],
            tools: [Tool(function_declarations: [makeInsertFunction()])],
            tool_config: ToolConfig(function_calling_config: FunctionCallingConfig(mode: "ANY"))
        )

        let response: GenerateResponse = try await send(body, modelID: modelID)

        if let call = response.firstFunctionCall,
           call.name == SamTools.insertTextName,
           let text = call.args?[SamTools.textArgName]?.stringValue,
           !text.isEmpty {
            return text
        }

        if let text = response.firstText, !text.isEmpty {
            return text
        }

        throw LLMError.noActionOutput
    }

    func sendChat(
        messages: [SamChatMessage],
        initialContext: SessionContext?,
        modelID: String
    ) async throws -> String {
        let payload = SamChat.apiMessages(from: messages, initialContext: initialContext)
        let contents = payload.map { entry in
            Content(
                role: entry.role == "user" ? "user" : "model",
                parts: [Part(text: entry.content, functionCall: nil)]
            )
        }

        let systemPrompt = await MainActor.run { SamChat.resolvedSystemPrompt() }
        let body = GenerateRequest(
            system_instruction: Content(role: nil, parts: [Part(text: systemPrompt, functionCall: nil)]),
            contents: contents,
            tools: nil,
            tool_config: nil
        )

        let response: GenerateResponse = try await send(body, modelID: modelID)
        if let text = response.firstText, !text.isEmpty {
            return text
        }
        throw LLMError.invalidResponse
    }

    func summarizeMeeting(transcript: String, modelID: String) async throws -> MeetingSummary {
        let systemPrompt = await MainActor.run { SamMeeting.resolvedSystemPrompt() }
        let body = GenerateRequest(
            system_instruction: Content(role: nil, parts: [Part(text: systemPrompt, functionCall: nil)]),
            contents: [Content(role: "user", parts: [Part(text: "Meeting-Transkript:\n\n\(transcript)", functionCall: nil)])],
            tools: nil,
            tool_config: nil
        )
        let response: GenerateResponse = try await send(body, modelID: modelID)
        guard let text = response.firstText, !text.isEmpty else {
            throw LLMError.invalidResponse
        }
        return try SamMeeting.parseSummaryJSON(text)
    }

    private func makeInsertFunction() -> FunctionDeclaration {
        FunctionDeclaration(
            name: SamTools.insertTextName,
            description: SamTools.insertTextDescription,
            parameters: ParametersSchema(
                properties: [SamTools.textArgName: PropertySchema(type: "string", description: "Der einzufügende Text")],
                required: [SamTools.textArgName]
            )
        )
    }

    private func send<T: Decodable>(_ body: GenerateRequest, modelID: String) async throws -> T {
        guard await authProvider.isConfigured else {
            throw LLMError.notConfigured
        }
        let apiKey = try await authProvider.apiKey()

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
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
            let message = (try? JSONDecoder().decode(GeminiErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unbekannter Fehler"
            logger.error("API error \(http.statusCode): \(message, privacy: .public)")
            throw LLMError.apiError(status: http.statusCode, message: message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API-Modelle

private struct GenerateRequest: Encodable {
    let system_instruction: Content?
    let contents: [Content]
    let tools: [Tool]?
    let tool_config: ToolConfig?
}

private struct Content: Encodable {
    let role: String?
    let parts: [Part]
}

private struct Part: Encodable {
    let text: String?
    let functionCall: GeminiFunctionCall?
}

private struct GeminiFunctionCall: Encodable {
    let name: String
}

private struct Tool: Encodable {
    let function_declarations: [FunctionDeclaration]
}

private struct FunctionDeclaration: Encodable {
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

private struct ToolConfig: Encodable {
    let function_calling_config: FunctionCallingConfig
}

private struct FunctionCallingConfig: Encodable {
    let mode: String
}

private struct GenerateResponse: Decodable {
    let candidates: [Candidate]?

    var firstText: String? {
        candidates?.first?.content?.parts?.compactMap { $0.text }.first
    }

    var firstFunctionCall: ResponseFunctionCall? {
        candidates?.first?.content?.parts?.compactMap { $0.functionCall }.first
    }

    struct Candidate: Decodable {
        let content: ResponseContent?
    }

    struct ResponseContent: Decodable {
        let parts: [ResponsePart]?
    }

    struct ResponsePart: Decodable {
        let text: String?
        let functionCall: ResponseFunctionCall?
    }

    struct ResponseFunctionCall: Decodable {
        let name: String
        let args: [String: JSONValue]?
    }
}

private struct GeminiErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
