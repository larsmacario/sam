import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "MeetingChunkTranscriber")

/// Transkribiert Meeting-Audio-Chunks mit Whisper lokal und Online-Fallback.
enum MeetingChunkTranscriber {
    private static let localTimeoutSeconds: UInt64 = 120

    static func transcribe(
        samples: [Float],
        localModel: WhisperLocalModel,
        onlineModel: WhisperOnlineModel,
        language: TranscriptionLanguage,
        forceOnline: Bool
    ) async throws -> String {
        guard samples.count > Int(AudioSampleCollector.targetSampleRate * 0.2) else { return "" }

        if !forceOnline {
            do {
                let text = try await withTimeout(seconds: localTimeoutSeconds) {
                    try await transcribeLocal(samples: samples, model: localModel, language: language)
                }
                if !text.isEmpty { return text }
            } catch {
                logger.warning("Lokale Transkription fehlgeschlagen, Fallback online: \(error.localizedDescription, privacy: .public)")
            }
        }

        return try await transcribeOnline(samples: samples, model: onlineModel, language: language)
    }

    private static func transcribeLocal(
        samples: [Float],
        model: WhisperLocalModel,
        language: TranscriptionLanguage
    ) async throws -> String {
        let transcriber = WhisperLocalTranscriber(model: model.rawValue, language: language.whisperCode)
        return try await transcriber.transcribeSamples(samples)
    }

    private static func transcribeOnline(
        samples: [Float],
        model: WhisperOnlineModel,
        language: TranscriptionLanguage
    ) async throws -> String {
        let transcriber = WhisperOnlineTranscriber(model: model.rawValue, language: language.whisperCode)
        return try await transcriber.transcribeSamples(samples)
    }

    private static func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw TranscriptionTimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

private struct TranscriptionTimeoutError: LocalizedError {
    var errorDescription: String? { "Lokale Transkription hat zu lange gedauert." }
}
