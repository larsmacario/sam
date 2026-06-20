import AppKit
import AVFoundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "AudioRecorder")

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case engineStartFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Mikrofon-Berechtigung wurde verweigert."
        case .engineStartFailed(let error):
            return "Audio-Engine konnte nicht gestartet werden: \(error.localizedDescription)"
        }
    }
}

/// Mikrofon-Berechtigung für AVAudioEngine (macOS 14+).
@MainActor
enum MicrophonePermissionService {
    nonisolated static var hasPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Erster Klick: nur macOS-Systemdialog. Erneuter Klick: nur Systemeinstellungen.
    static func requestPermission(onRefresh: (@MainActor () -> Void)? = nil) {
        Task { @MainActor in
            if hasPermission {
                onRefresh?()
                return
            }

            let status = AVAudioApplication.shared.recordPermission
            if status == .denied {
                openSystemSettings()
                scheduleRefresh(onRefresh)
                return
            }

            if !hasPromptedThisSession {
                hasPromptedThisSession = true
                _ = await requestPermission()
                triggerMicrophoneRegistration()
            } else {
                openSystemSettings()
            }
            scheduleRefresh(onRefresh)
        }
    }

    private static var hasPromptedThisSession = false

    /// Kurz den Audio-Input ansprechen — registriert die App bei macOS für Mikrofon-Datenschutz.
    private static func triggerMicrophoneRegistration() {
        let engine = AVAudioEngine()
        _ = engine.inputNode
        engine.prepare()
    }

    private static func scheduleRefresh(_ onRefresh: (@MainActor () -> Void)?) {
        guard let onRefresh else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            onRefresh()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            onRefresh()
        }
    }
}

/// Nimmt Audio über AVAudioEngine auf und liefert PCM-Buffer.
final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "de.larsmacario.sam.audio-recorder")
    private var isRecording = false

    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?

    static func requestPermission() async -> Bool {
        await MicrophonePermissionService.requestPermission()
    }

    static var hasPermission: Bool {
        MicrophonePermissionService.hasPermission
    }

    func start() throws {
        guard !isRecording else { return }
        guard Self.hasPermission else {
            throw AudioRecorderError.permissionDenied
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            isRecording = true
            logger.info("Audioaufnahme gestartet")
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineStartFailed(error)
        }
    }

    func stop() {
        guard isRecording else { return }
        queue.sync {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRecording = false
            logger.info("Audioaufnahme gestoppt")
        }
    }
}
