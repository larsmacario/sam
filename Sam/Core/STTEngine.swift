import Foundation

/// Verfügbare Spracherkennungs-Engines (Sprache → Text).
enum STTEngine: String, CaseIterable, Identifiable, Sendable {
    /// Apple SFSpeechRecognizer on-device – streamt Live-Text während des Sprechens.
    case appleOnDevice
    /// Whisper lokal via WhisperKit (CoreML) – Batch, offline, Modell-Download nötig.
    case whisperLocal
    /// Whisper über OpenAI-API – Batch, Cloud, nutzt den OpenAI-API-Key.
    case whisperOnline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleOnDevice: return "Apple (on-device, live)"
        case .whisperLocal: return "Whisper lokal"
        case .whisperOnline: return "Whisper online (OpenAI)"
        }
    }

    /// Nur Apple liefert Live-Teiltranskripte während des Sprechens.
    var supportsLivePartials: Bool { self == .appleOnDevice }

    var needsModelDownload: Bool { self == .whisperLocal }
    var needsOpenAIKey: Bool { self == .whisperOnline }
}

/// Lokale WhisperKit-Modelle (Qualität vs. Größe/Geschwindigkeit).
enum WhisperLocalModel: String, CaseIterable, Identifiable, Sendable {
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case largeTurbo = "openai_whisper-large-v3-v20240930_turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .base: return "base (~150 MB, schnell)"
        case .small: return "small (~500 MB, empfohlen)"
        case .largeTurbo: return "large-v3-turbo (~1,5 GB, beste Qualität)"
        }
    }
}

/// Transkriptionssprache (gilt für alle STT-Engines). Default Deutsch, da feste
/// Sprache bei kurzen Phrasen zuverlässiger ist als automatische Erkennung.
enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case german
    case english
    case automatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "Englisch"
        case .automatic: return "Automatisch"
        }
    }

    /// Locale für Apple SFSpeechRecognizer (nil = automatische Reihenfolge).
    var appleLocaleIdentifier: String? {
        switch self {
        case .german: return "de-DE"
        case .english: return "en-US"
        case .automatic: return nil
        }
    }

    /// ISO-Code für Whisper (nil = automatische Erkennung).
    var whisperCode: String? {
        switch self {
        case .german: return "de"
        case .english: return "en"
        case .automatic: return nil
        }
    }
}

/// OpenAI-Transkriptionsmodelle für Whisper online.
enum WhisperOnlineModel: String, CaseIterable, Identifiable, Sendable {
    case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"
    case whisper1 = "whisper-1"
    case gpt4oTranscribe = "gpt-4o-transcribe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4oMiniTranscribe: return "gpt-4o-mini-transcribe (empfohlen)"
        case .whisper1: return "whisper-1 (klassisch)"
        case .gpt4oTranscribe: return "gpt-4o-transcribe (beste Qualität)"
        }
    }
}
