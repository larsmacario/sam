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
    @Published var screenCaptureGranted = false

    private var monitorTask: Task<Void, Never>?

    private let settings = SettingsStore.shared
    private let hotkeyManager = HotkeyManager.shared
    private let audioRecorder = AudioRecorder()
    private let overlay = OverlayWindowController.shared

    private var transcriber: (any Transcribing)?
    private var isSessionActive = false
    /// Im KI-Modus beim Hotkey-Press erfasster Kontext (Markierung noch aktiv).
    private var aiSessionContext: SessionContext?

    private init() {}

    func bootstrap() {
        showOnboarding = !settings.hasCompletedOnboarding
        setupHotkeyCallbacks()
        refreshPermissions()
        startPermissionMonitoring()
        if settings.inputMode == .meeting {
            overlay.showMeetingModeIdle()
        }
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

    var allRequiredPermissionsGranted: Bool {
        accessibilityGranted && microphoneGranted && speechGranted
    }

    func refreshPermissions() {
        let ax = hotkeyManager.isAccessibilityGranted
        let axWas = accessibilityGranted

        accessibilityGranted = ax
        microphoneGranted = AudioRecorder.hasPermission
        speechGranted = SpeechTranscriber.hasPermission
        screenCaptureGranted = ScreenCapturePermissionService.hasPermission

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

        if allRequiredPermissionsGranted && !settings.hasCompletedOnboarding {
            completeOnboarding()
        }
    }

    /// Schließt das Einrichtungsfenster, sobald alle Pflicht-Berechtigungen erteilt sind.
    func completeOnboarding() {
        guard !settings.hasCompletedOnboarding else { return }
        settings.hasCompletedOnboarding = true
        showOnboarding = false
        restartHotkey()
        NotificationCenter.default.post(name: .samOnboardingCompleted, object: nil)
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
        setInputMode(settings.inputMode.toggled())
    }

    /// Setzt den Eingabemodus (Settings-Picker oder fn+⌥).
    func setInputMode(_ mode: InputMode) {
        guard !isSessionActive else { return }
        let previousMode = settings.inputMode
        guard previousMode != mode else { return }

        settings.inputMode = mode

        if previousMode == .chat {
            ChatSessionController.shared.reset()
        }

        if previousMode == .meeting {
            Task {
                if MeetingSessionController.shared.isActive {
                    await stopMeeting()
                }
                overlay.hideMeetingMode()
                if mode != .meeting {
                    overlay.flashMode(mode)
                }
            }
        } else if mode == .meeting {
            overlay.showMeetingModeIdle()
        } else {
            overlay.hideMeetingMode()
            overlay.flashMode(mode)
        }

        logger.info("Eingabemodus gewechselt: \(mode.rawValue, privacy: .public)")
    }

    func closeChatSession() {
        ChatSessionController.shared.reset()
    }

    func sendChatText(_ text: String) async {
        guard settings.inputMode == .chat else { return }
        guard !ChatSessionController.shared.isProcessing else { return }

        guard settings.isActiveProviderConfigured else {
            errorMessage = AuthError.notConfigured.localizedDescription
            status = .error
            overlay.showAnswer("Bitte hinterlege zuerst einen API-Key für \(settings.selectedProvider.displayName) in den Einstellungen.")
            return
        }

        status = .processing
        do {
            let context = ChatSessionController.shared.hasActiveSession ? nil : ContextProvider.shared.capture()
            try await ChatSessionController.shared.send(text: text, context: context)
            status = .idle
        } catch {
            errorMessage = error.localizedDescription
            status = .error
        }
    }

    private func handleHotkeyPress() async {
        guard !isSessionActive else { return }

        if settings.inputMode == .meeting {
            isSessionActive = true
            overlay.setMeetingHotkeyPressed(true)
            return
        }

        if settings.inputMode == .chat && ChatSessionController.shared.isProcessing {
            return
        }
        isSessionActive = true
        status = .listening
        errorMessage = nil

        if settings.inputMode == .ai {
            aiSessionContext = ContextProvider.shared.capture()
        }

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
        if settings.inputMode == .meeting {
            guard isSessionActive else { return }
            isSessionActive = false
            overlay.setMeetingHotkeyPressed(false)

            if MeetingSessionController.shared.isActive {
                await stopMeeting()
            } else {
                await presentMeetingStartDialog()
            }
            return
        }

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
            aiSessionContext = nil
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
            aiSessionContext = nil
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

        guard settings.isActiveProviderConfigured else {
            aiSessionContext = nil
            errorMessage = AuthError.notConfigured.localizedDescription
            status = .error
            overlay.showAnswer("Bitte hinterlege zuerst einen API-Key für \(settings.selectedProvider.displayName) in den Einstellungen – oder wechsle mit fn+Option in den Diktat-Modus.")
            return
        }

        // KI-Modus: Ein-Turn-Aktion am Cursor, Ergebnis einfügen oder im Chat anzeigen.
        if settings.inputMode == .ai {
            status = .processing
            logger.info("KI-Aktion an \(self.settings.selectedProvider.rawValue, privacy: .public) (\(self.settings.currentModelID, privacy: .public))…")
            let context = aiSessionContext ?? ContextProvider.shared.capture()
            aiSessionContext = nil
            do {
                let client = LLMClientFactory.make(for: settings.selectedProvider)
                let result = try await client.processAction(
                    transcript: transcript,
                    context: context,
                    modelID: settings.currentModelID
                )

                let showInChat = context.selectedText.map { !$0.isEmpty } == true
                    && !context.hasEditableInsertionPoint

                if showInChat {
                    ChatSessionController.shared.presentAIResult(
                        instruction: transcript,
                        result: result,
                        context: context
                    )
                } else {
                    try await OutputRouter.shared.route(.insertText(result))
                    overlay.showInsertUndoToast {
                        Task { @MainActor in
                            await OutputRouter.shared.undoLastInsert()
                        }
                    }
                }
                status = .idle
            } catch {
                aiSessionContext = nil
                logger.error("KI-Fehler: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                status = .error
                overlay.showAnswer("Fehler: \(error.localizedDescription)")
            }
            return
        }

        // Chat: Mehrturn-Dialog im Chat-Fenster.
        status = .processing
        logger.info("Chat-Nachricht (Sprache): Länge=\(transcript.count)")
        do {
            let context = ChatSessionController.shared.hasActiveSession ? nil : ContextProvider.shared.capture()
            try await ChatSessionController.shared.send(text: transcript, context: context)
            status = .idle
        } catch {
            logger.error("Chat-Fehler: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            status = .error
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

    func requestScreenCapturePermission() {
        ScreenCapturePermissionService.requestPermission { [weak self] in
            self?.refreshPermissions()
        }
    }

    func requestSpeechPermission() {
        SpeechPermissionService.requestPermission { [weak self] in
            self?.refreshPermissions()
        }
    }

    func startMeeting(title: String?) async {
        guard !MeetingSessionController.shared.isActive else { return }

        do {
            let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let meetingTitle = (trimmed?.isEmpty == false) ? trimmed : nil
            try await MeetingSessionController.shared.start(title: meetingTitle)
            status = .idle
        } catch {
            errorMessage = error.localizedDescription
            status = .error
            overlay.showAnswer("Meeting konnte nicht gestartet werden: \(error.localizedDescription)")
            if settings.inputMode == .meeting {
                overlay.showMeetingModeIdle()
            }
        }
    }

    func stopMeeting() async {
        guard MeetingSessionController.shared.isActive else { return }
        status = .processing
        await MeetingSessionController.shared.stop()
        status = .idle
        if settings.inputMode == .meeting {
            overlay.showMeetingModeIdle()
        }
    }

    private func presentMeetingStartDialog() async {
        guard canStartMeeting else {
            overlay.showAnswer("Für Meetings fehlen Berechtigungen. Prüfe Mikrofon und ggf. Bildschirmaufnahme in den Einstellungen.")
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            overlay.showMeetingStartSheet(
                onStart: { [weak self] title in
                    Task { @MainActor in
                        await self?.startMeeting(title: title)
                        continuation.resume()
                    }
                },
                onCancel: {
                    continuation.resume()
                }
            )
        }
    }

    var canStartMeeting: Bool {
        let source = settings.meetingAudioSource
        if source.needsMicrophone, !microphoneGranted { return false }
        if source.needsSystemAudio, !screenCaptureGranted { return false }
        return true
    }
}

extension Notification.Name {
    static let samOnboardingCompleted = Notification.Name("samOnboardingCompleted")
}
