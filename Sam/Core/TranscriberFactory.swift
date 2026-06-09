import Foundation

/// Erzeugt den passenden Transcriber für die gewählte STT-Engine.
enum TranscriberFactory {
    static func make(
        engine: STTEngine,
        localModel: WhisperLocalModel,
        onlineModel: WhisperOnlineModel,
        language: TranscriptionLanguage
    ) -> any Transcribing {
        switch engine {
        case .appleOnDevice:
            return SpeechTranscriber(preferredLocale: language.appleLocaleIdentifier)
        case .whisperOnline:
            return WhisperOnlineTranscriber(model: onlineModel.rawValue, language: language.whisperCode)
        case .whisperLocal:
            return WhisperLocalTranscriber(model: localModel.rawValue, language: language.whisperCode)
        }
    }
}
