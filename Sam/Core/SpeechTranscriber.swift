import AVFoundation
import Speech
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "SpeechTranscriber")

enum SpeechTranscriberError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Spracherkennungs-Berechtigung wurde verweigert."
        case .recognizerUnavailable:
            return "Spracherkennung ist für diese Sprache nicht verfügbar."
        case .requestFailed:
            return "Spracherkennungs-Anfrage konnte nicht gestartet werden."
        }
    }
}

/// Lokale Spracherkennung via SFSpeechRecognizer (on-device). Streamt Live-Teiltranskripte.
final class SpeechTranscriber: Transcribing, @unchecked Sendable {
    private(set) var partialTranscript = ""
    private(set) var finalTranscript = ""

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let lock = NSLock()
    private let locales: [Locale]

    var onPartial: (@Sendable (String) -> Void)?

    /// preferredLocale (z.B. "de-DE") erzwingt eine Sprache; nil → Deutsch bevorzugt, dann Englisch.
    init(preferredLocale: String? = nil) {
        if let preferredLocale {
            locales = [Locale(identifier: preferredLocale)]
        } else {
            locales = [Locale(identifier: "de-DE"), Locale(identifier: "en-US")]
        }
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static var hasPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func start() throws {
        reset()
        guard Self.hasPermission else {
            throw SpeechTranscriberError.permissionDenied
        }

        guard let recognizer = firstAvailableRecognizer() else {
            throw SpeechTranscriberError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.lock.lock()
                self.partialTranscript = text
                if result.isFinal {
                    self.finalTranscript = text
                }
                self.lock.unlock()
                self.onPartial?(text)
            }
            if let error {
                logger.error("Spracherkennungsfehler: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard task != nil else {
            throw SpeechTranscriberError.requestFailed
        }

        logger.info("Spracherkennung gestartet (\(recognizer.locale.identifier, privacy: .public))")
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func finish() async throws -> String {
        request?.endAudio()
        try? await Task.sleep(nanoseconds: 300_000_000)

        // withLock statt lock()/unlock(): async-sicheres scoped locking (Swift 6).
        let result = lock.withLock {
            (finalTranscript.isEmpty ? partialTranscript : finalTranscript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        task?.cancel()
        task = nil
        request = nil
        recognizer = nil

        logger.info("Spracherkennung beendet, Länge: \(result.count)")
        return result
    }

    func reset() {
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        lock.lock()
        partialTranscript = ""
        finalTranscript = ""
        lock.unlock()
    }

    private func firstAvailableRecognizer() -> SFSpeechRecognizer? {
        for locale in locales {
            if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable {
                return recognizer
            }
        }
        return nil
    }
}
