import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "MeetingTranscriptionQueue")

/// Serialisiert Whisper-Transkriptionen für Meeting-Chunks (WhisperKit nur seriell).
actor MeetingTranscriptionQueue {
    static let shared = MeetingTranscriptionQueue()

    private struct Job: Sendable {
        let samples: [Float]
        let localModel: WhisperLocalModel
        let onlineModel: WhisperOnlineModel
        let language: TranscriptionLanguage
        let forceOnline: Bool
    }

    private var pending: [CheckedContinuation<String, Error>] = []
    private var pendingJobs: [Job] = []
    private var isProcessing = false

    private init() {}

    func transcribe(
        samples: [Float],
        localModel: WhisperLocalModel,
        onlineModel: WhisperOnlineModel,
        language: TranscriptionLanguage,
        forceOnline: Bool
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            pendingJobs.append(
                Job(
                    samples: samples,
                    localModel: localModel,
                    onlineModel: onlineModel,
                    language: language,
                    forceOnline: forceOnline
                )
            )
            pending.append(continuation)
            startProcessingIfNeeded()
        }
    }

    private func startProcessingIfNeeded() {
        guard !isProcessing else { return }
        isProcessing = true
        Task { await processLoop() }
    }

    private func processLoop() async {
        while !pendingJobs.isEmpty, !pending.isEmpty {
            let job = pendingJobs.removeFirst()
            let continuation = pending.removeFirst()

            do {
                let text = try await MeetingChunkTranscriber.transcribe(
                    samples: job.samples,
                    localModel: job.localModel,
                    onlineModel: job.onlineModel,
                    language: job.language,
                    forceOnline: job.forceOnline
                )
                continuation.resume(returning: text)
            } catch {
                logger.error("Queue-Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                continuation.resume(throwing: error)
            }
        }
        isProcessing = false
    }
}
