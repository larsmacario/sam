import AVFoundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "WhisperOnlineTranscriber")

/// Whisper über die OpenAI-Transkriptions-API (Batch). Nutzt den OpenAI-API-Key.
final class WhisperOnlineTranscriber: Transcribing, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?

    private let collector = AudioSampleCollector()
    private let authProvider: AuthProviding
    private let model: String
    private let language: String?
    private let session: URLSession

    init(model: String, language: String? = nil, authProvider: AuthProviding = APIKeyAuthProvider(provider: .openai), session: URLSession = .shared) {
        self.model = model
        self.language = language
        self.authProvider = authProvider
        self.session = session
    }

    func start() throws {
        collector.reset()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        collector.append(buffer)
    }

    func finish() async throws -> String {
        let samples = collector.drain()
        return try await transcribeSamples(samples)
    }

    /// Transkribiert vorgegebene Samples (Meeting-Chunks, Online-Fallback).
    func transcribeSamples(_ samples: [Float]) async throws -> String {
        guard samples.count > Int(AudioSampleCollector.targetSampleRate * 0.2) else { return "" }

        guard await authProvider.isConfigured else {
            throw LLMError.notConfigured
        }
        let apiKey = try await authProvider.apiKey()
        let wav = WAVEncoder.encode(samples: samples)

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, wav: wav)

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
            let message = (try? JSONDecoder().decode(OpenAITranscriptionError.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unbekannter Fehler"
            logger.error("Transcription error \(http.statusCode): \(message, privacy: .public)")
            throw LLMError.apiError(status: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func multipartBody(boundary: String, wav: Data) -> Data {
        var body = Data()
        func appendString(_ string: String) {
            body.append(contentsOf: Array(string.utf8))
        }

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        appendString("Content-Type: audio/wav\r\n\r\n")
        body.append(wav)
        appendString("\r\n")

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        appendString("\(model)\r\n")

        if let language {
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            appendString("\(language)\r\n")
        }

        appendString("--\(boundary)--\r\n")
        return body
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct OpenAITranscriptionError: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}
