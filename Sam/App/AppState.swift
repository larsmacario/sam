import AppKit
import os
import SwiftUI

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "AppState")

enum AppStatus: String {
    case idle
    case listening
    case processing
    case error

    var menuBarSymbol: String {
        switch self {
        case .idle: return "waveform.circle"
        case .listening: return "waveform.circle.fill"
        case .processing: return "ellipsis.circle"
        case .error: return "exclamationmark.circle"
        }
    }

    var statusLabel: String {
        switch self {
        case .idle: return "Bereit"
        case .listening: return "Hört zu"
        case .processing: return "Verarbeitet…"
        case .error: return "Fehler"
        }
    }

    var statusColor: Color {
        switch self {
        case .idle: return SamDesign.success
        case .listening: return SamDesign.accent
        case .processing: return SamDesign.warning
        case .error: return Color.red
        }
    }
}

/// Zentraler Orchestrator für Hotkey → Aufnahme → STT → Claude → Ausgabe.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var status: AppStatus = .idle
    @Published var errorMessage: String?
    @Published var showOnboarding = false

    // Live-Berechtigungsstatus (vom Monitor aktualisiert → reaktive UI).
    @Published var accessibilityGranted = false
    @Published var microphoneGranted = false
    @Published var speechGranted = false

    private var monitorTask: Task<Void, Never>?

    private let settings = SettingsStore.shared
    private let hotkeyManager = HotkeyManager.shared
    private let audioRecorder = AudioRecorder()
    private let overlay = OverlayWindowController.shared

    private var transcriber: (any Transcribing)?
    private var isSessionActive = false

    private init() {}

    func bootstrap() {
        showOnboarding = !settings.hasCompletedOnboarding
        setupHotkeyCallbacks()
        refreshPermissions()
        startPermissionMonitoring()
    }

    /// Pollt den Berechtigungsstatus, aktualisiert die UI live und startet den
    /// Hotkey automatisch, sobald Accessibility erteilt wird (ohne App-Neustart).
    func startPermissionMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func refreshPermissions() {
        let ax = hotkeyManager.isAccessibilityGranted
        let axWas = accessibilityGranted

        accessibilityGranted = ax
        microphoneGranted = AudioRecorder.hasPermission
        speechGranted = SpeechTranscriber.hasPermission

        if ax && !axWas {
            restartHotkey()
        } else if ax && !hotkeyManager.isRunning {
            restartHotkey()
        } else if !ax && axWas {
            // Berechtigung entzogen → Hotkey stoppen und Hinweis zeigen.
            hotkeyManager.stop()
            errorMessage = "Bedienungshilfen-Freigabe fehlt für den Hotkey."
            status = .error
        }
    }

    func restartHotkey() {
        hotkeyManager.stop()
        let started = hotkeyManager.start()
        if started {
            if status == .error { status = .idle }
            errorMessage = nil
        } else if !hotkeyManager.isAccessibilityGranted {
            errorMessage = nil
            if status == .error { status = .idle }
        } else {
            logger.warning("Hotkey konnte nicht gestartet werden")
        }
    }

    private func setupHotkeyCallbacks() {
        hotkeyManager.onPress = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPress()
            }
        }
        hotkeyManager.onRelease = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyRelease()
            }
        }
        hotkeyManager.onToggleMode = { [weak self] in
            Task { @MainActor in
                self?.toggleInputMode()
            }
        }
    }

    /// Wechselt den Eingabemodus (fn+option) und zeigt ihn klar sichtbar in der Pille.
    func toggleInputMode() {
        guard !isSessionActive else { return }
        settings.inputMode = settings.inputMode.toggled()
        overlay.flashMode(settings.inputMode)
        logger.info("Eingabemodus gewechselt: \(self.settings.inputMode.rawValue, privacy: .public)")
    }

    private func handleHotkeyPress() async {
        guard !isSessionActive else { return }
        isSessionActive = true
        status = .listening
        errorMessage = nil

        overlay.showRecording(mode: settings.inputMode)
        logger.info("Aufnahme gestartet: Modus=\(self.settings.inputMode.rawValue, privacy: .public) Engine=\(self.settings.sttEngine.rawValue, privacy: .public)")

        let transcriber = TranscriberFactory.make(
            engine: settings.sttEngine,
            localModel: settings.whisperLocalModel,
            onlineModel: settings.whisperOnlineModel,
            language: settings.transcriptionLanguage
        )
        self.transcriber = transcriber

        do {
            // Nur Apple liefert Live-Teiltranskripte für die Pille.
            if settings.sttEngine.supportsLivePartials {
                transcriber.onPartial = { [weak self] text in
                    Task { @MainActor in
                        self?.overlay.updateRecordingTranscript(text)
                    }
                }
            }
            try transcriber.start()
            audioRecorder.onBuffer = { [weak transcriber] buffer in
                transcriber?.append(buffer)
            }
            try audioRecorder.start()
        } catch {
            logger.error("Aufnahme-Start fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            status = .error
            isSessionActive = false
            self.transcriber = nil
            overlay.hideRecording()
        }
    }

    private func handleHotkeyRelease() async {
        guard isSessionActive else { return }

        audioRecorder.stop()

        // Batch-Engines (Whisper) liefern keinen Live-Text → Feedback anzeigen.
        if !settings.sttEngine.supportsLivePartials {
            status = .processing
            overlay.updateRecordingTranscript("Transkribiere…")
        }

        let transcript: String
        do {
            transcript = try await (transcriber?.finish() ?? "")
        } catch {
            logger.error("Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            overlay.hideRecording()
            isSessionActive = false
            transcriber = nil
            errorMessage = error.localizedDescription
            status = .error
            overlay.showAnswer("Fehler bei der Transkription: \(error.localizedDescription)")
            return
        }

        overlay.hideRecording()
        isSessionActive = false
        transcriber = nil

        logger.info("Transkript fertig: Länge=\(transcript.count), Modus=\(self.settings.inputMode.rawValue, privacy: .public)")

        guard !transcript.isEmpty else {
            logger.info("Transkript leer → Abbruch")
            status = .idle
            return
        }

        // Diktat-Modus: Transkript direkt einfügen, kein KI-Aufruf, kein API-Key nötig.
        if settings.inputMode == .dictation {
            do {
                try await OutputRouter.shared.route(.insertText(transcript))
                status = .idle
            } catch {
                logger.error("Einfügen fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                status = .error
                overlay.showAnswer("Fehler: \(error.localizedDescription)")
            }
            return
        }

        // KI-Modus: Transkript an die KI, die per Tool-Use über die Ausgabe entscheidet.
        guard settings.isActiveProviderConfigured else {
            errorMessage = AuthError.notConfigured.localizedDescription
            status = .error
            overlay.showAnswer("Bitte hinterlege zuerst einen API-Key für \(settings.selectedProvider.displayName) in den Einstellungen – oder wechsle mit fn+Option in den Diktat-Modus.")
            return
        }

        status = .processing
        logger.info("KI-Anfrage an \(self.settings.selectedProvider.rawValue, privacy: .public) (\(self.settings.currentModelID, privacy: .public))…")

        do {
            let context = ContextProvider.shared.capture()
            let client = LLMClientFactory.make(for: settings.selectedProvider)
            let action = try await client.processTranscript(
                transcript: transcript,
                context: context,
                modelID: settings.currentModelID
            )
            switch action {
            case .insertText: logger.info("KI-Antwort: insert_text → einfügen")
            case .showAnswer: logger.info("KI-Antwort: show_answer → Fenster")
            }
            try await OutputRouter.shared.route(action)
            status = .idle
        } catch {
            logger.error("Pipeline-Fehler: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            status = .error
            overlay.showAnswer("Fehler: \(error.localizedDescription)")
        }
    }

    func openAccessibilitySettings() {
        AccessibilityPermissionService.openSystemSettings()
    }

    func requestAccessibilityPermission() {
        AccessibilityPermissionService.requestPermission { [weak self] in
            self?.refreshPermissions()
        }
    }

    func requestMicrophonePermission() {
        MicrophonePermissionService.requestPermission { [weak self] in
            self?.refreshPermissions()
        }
    }
}
