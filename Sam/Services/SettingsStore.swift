import Foundation
import SwiftUI

/// Zentraler Einstellungsspeicher: UserDefaults (API-Keys lokal, ohne Keychain).
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @AppStorage("selectedProvider") private var selectedProviderRaw: String = LLMProvider.claude.rawValue
    @AppStorage("inputMode") private var inputModeRaw: String = InputMode.ai.rawValue
    @AppStorage("sttEngine") private var sttEngineRaw: String = STTEngine.appleOnDevice.rawValue
    @AppStorage("whisperLocalModel") private var whisperLocalModelRaw: String = WhisperLocalModel.small.rawValue
    @AppStorage("whisperOnlineModel") private var whisperOnlineModelRaw: String = WhisperOnlineModel.gpt4oMiniTranscribe.rawValue
    @AppStorage("transcriptionLanguage") private var transcriptionLanguageRaw: String = TranscriptionLanguage.german.rawValue
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("meetingAudioSource") private var meetingAudioSourceRaw: String = MeetingAudioSource.microphone.rawValue
    @AppStorage("meetingChunkIntervalSeconds") var meetingChunkIntervalSeconds: Double = 60
    @AppStorage("meetingOnlineFallbackAfterMinutes") var meetingOnlineFallbackAfterMinutes: Double = 45
    @AppStorage("hasAcknowledgedMeetingRecordingNotice") var hasAcknowledgedMeetingRecordingNotice: Bool = false
    @AppStorage("meetingStorageDirectoryPath") var meetingStorageDirectoryPath: String = ""

    /// Provider, deren API-Key aktuell hinterlegt ist (für reaktive UI).
    @Published var configuredProviders: Set<LLMProvider> = []
    @Published var lastConnectionTestResult: String?

    /// Benutzerdefinierte Eigennamen (Label + Wert).
    @Published private(set) var properNames: [ProperNameEntry] = []

    var selectedProvider: LLMProvider {
        get { LLMProvider(rawValue: selectedProviderRaw) ?? .claude }
        set {
            objectWillChange.send()
            selectedProviderRaw = newValue.rawValue
        }
    }

    /// Aktiver Eingabemodus (Diktat, KI oder Chat), umgeschaltet per fn+Option.
    var inputMode: InputMode {
        get { InputMode(rawValue: inputModeRaw) ?? .ai }
        set {
            objectWillChange.send()
            inputModeRaw = newValue.rawValue
        }
    }

    /// Aktive Spracherkennungs-Engine (Sprache → Text).
    var sttEngine: STTEngine {
        get { STTEngine(rawValue: sttEngineRaw) ?? .appleOnDevice }
        set {
            objectWillChange.send()
            sttEngineRaw = newValue.rawValue
        }
    }

    var whisperLocalModel: WhisperLocalModel {
        get { WhisperLocalModel(rawValue: whisperLocalModelRaw) ?? .small }
        set {
            objectWillChange.send()
            whisperLocalModelRaw = newValue.rawValue
        }
    }

    var whisperOnlineModel: WhisperOnlineModel {
        get { WhisperOnlineModel(rawValue: whisperOnlineModelRaw) ?? .gpt4oMiniTranscribe }
        set {
            objectWillChange.send()
            whisperOnlineModelRaw = newValue.rawValue
        }
    }

    var transcriptionLanguage: TranscriptionLanguage {
        get { TranscriptionLanguage(rawValue: transcriptionLanguageRaw) ?? .german }
        set {
            objectWillChange.send()
            transcriptionLanguageRaw = newValue.rawValue
        }
    }

    var meetingAudioSource: MeetingAudioSource {
        get { MeetingAudioSource(rawValue: meetingAudioSourceRaw) ?? .microphone }
        set {
            objectWillChange.send()
            meetingAudioSourceRaw = newValue.rawValue
        }
    }

    /// Aktiver Speicherordner für Meeting-Historie (JSON-Dateien).
    var meetingStorageDirectoryURL: URL {
        let custom = meetingStorageDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return MeetingStore.defaultStorageDirectory
    }

    var usesCustomMeetingStorageDirectory: Bool {
        !meetingStorageDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var meetingStorageDirectoryDisplayPath: String {
        Self.shortenedPath(meetingStorageDirectoryURL.path)
    }

    func resetMeetingStorageDirectory() {
        meetingStorageDirectoryPath = ""
        objectWillChange.send()
    }

    static func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private static let properNamesKey = "properNames"

    private init() {
        loadProperNames()
        refreshConfiguredProviders()
    }

    // MARK: - Eigennamen

    /// Anzeigename des Assistenten in der UI; Fallback „SAM“.
    var assistantDisplayName: String {
        value(forLabel: ProperNameLabel.assistantName) ?? "SAM"
    }

    /// Name des Nutzers für KI-Prompts; Fallback „Der Nutzer“.
    var userDisplayName: String {
        value(forLabel: ProperNameLabel.userName) ?? "Der Nutzer"
    }

    /// Gültige Einträge für den KI-Kontextblock.
    var validProperNames: [ProperNameEntry] {
        properNames.filter(\.isValid)
    }

    func value(forLabel label: String) -> String? {
        guard let entry = properNames.first(where: { ProperNameLabel.matches($0.label, label) }),
              entry.isValid else { return nil }
        return entry.trimmedValue
    }

    func addProperName(label: String = "", value: String = "") {
        properNames.append(ProperNameEntry(label: label, value: value))
        persistProperNames()
    }

    func updateProperName(_ entry: ProperNameEntry) {
        guard let index = properNames.firstIndex(where: { $0.id == entry.id }) else { return }
        properNames[index] = entry
        persistProperNames()
    }

    func removeProperName(id: UUID) {
        properNames.removeAll { $0.id == id }
        persistProperNames()
    }

    private func loadProperNames() {
        guard let data = defaults.data(forKey: Self.properNamesKey),
              let decoded = try? JSONDecoder().decode([ProperNameEntry].self, from: data) else {
            properNames = []
            return
        }
        properNames = decoded
    }

    private func persistProperNames() {
        if let data = try? JSONEncoder().encode(properNames) {
            defaults.set(data, forKey: Self.properNamesKey)
        }
        objectWillChange.send()
    }

    // MARK: - Modell-Wahl (pro Provider gemerkt)

    private func modelDefaultsKey(_ provider: LLMProvider) -> String {
        "selectedModel.\(provider.rawValue)"
    }

    private func apiKeyDefaultsKey(_ provider: LLMProvider) -> String {
        "apiKey.\(provider.rawValue)"
    }

    /// Frei eingetragene Modell-ID pro Provider (Fallback: Standardmodell).
    func modelID(for provider: LLMProvider) -> String {
        let stored = defaults.string(forKey: modelDefaultsKey(provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty { return stored }
        return provider.defaultModel.id
    }

    func setModelID(_ id: String, for provider: LLMProvider) {
        defaults.set(id.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelDefaultsKey(provider))
    }

    /// Aktuell aktive Modell-ID (des gewählten Providers).
    var currentModelID: String {
        modelID(for: selectedProvider)
    }

    // MARK: - API-Key-Verwaltung (pro Provider, UserDefaults)

    func readAPIKey(for provider: LLMProvider) -> String? {
        let key = defaults.string(forKey: apiKeyDefaultsKey(provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    func refreshConfiguredProviders() {
        configuredProviders = Set(LLMProvider.allCases.filter { readAPIKey(for: $0) != nil })
    }

    func isConfigured(_ provider: LLMProvider) -> Bool {
        configuredProviders.contains(provider)
    }

    var isActiveProviderConfigured: Bool {
        isConfigured(selectedProvider)
    }

    func saveAPIKey(_ key: String, for provider: LLMProvider) {
        defaults.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyDefaultsKey(provider))
        refreshConfiguredProviders()
    }

    func deleteAPIKey(for provider: LLMProvider) {
        defaults.removeObject(forKey: apiKeyDefaultsKey(provider))
        refreshConfiguredProviders()
    }

    func maskedAPIKeyPreview(for provider: LLMProvider) -> String {
        guard let key = readAPIKey(for: provider), key.count > 8 else {
            return isConfigured(provider) ? "••••••••" : ""
        }
        return String(key.prefix(7)) + "…" + String(key.suffix(4))
    }
}
