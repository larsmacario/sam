import AVFoundation
import WhisperKit
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "WhisperLocalTranscriber")

/// Whisper lokal via WhisperKit (CoreML, Batch, offline).
/// Das Modell wird beim ersten Mal von Hugging Face geladen und danach zwischengespeichert.
final class WhisperLocalTranscriber: Transcribing, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?

    private let collector = AudioSampleCollector()
    private let model: String
    private let language: String?

    // Pipeline-Cache: WhisperKit-Laden ist teuer; SAM transkribiert immer nur seriell.
    nonisolated(unsafe) private static var cachedPipe: WhisperKit?
    nonisolated(unsafe) private static var cachedModel: String?

    init(model: String, language: String? = nil) {
        self.model = model
        self.language = language
    }

    func start() throws {
        collector.reset()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        collector.append(buffer)
    }

    func finish() async throws -> String {
        let samples = collector.drain()
        guard samples.count > Int(AudioSampleCollector.targetSampleRate * 0.2) else { return "" }

        let pipe = try await pipeline()
        let options = DecodingOptions(language: language)
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pipeline() async throws -> WhisperKit {
        if let cached = Self.cachedPipe, Self.cachedModel == model {
            return cached
        }
        logger.info("Lade WhisperKit-Modell \(self.model, privacy: .public)…")
        let pipe = try await WhisperKit(WhisperKitConfig(model: model))
        Self.cachedPipe = pipe
        Self.cachedModel = model
        return pipe
    }
}
