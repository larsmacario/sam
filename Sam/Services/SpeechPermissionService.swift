import AppKit
import Speech

/// Spracherkennungs-Berechtigung für Apple-on-Device STT.
@MainActor
enum SpeechPermissionService {
    private static var hasPromptedThisSession = false

    static var hasPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Erster Klick: nur macOS-Systemdialog. Erneuter Klick: nur Systemeinstellungen.
    static func requestPermission(onRefresh: (@MainActor () -> Void)? = nil) {
        if hasPermission {
            onRefresh?()
            return
        }

        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .denied {
            openSystemSettings()
            scheduleRefresh(onRefresh)
            return
        }

        Task { @MainActor in
            if !hasPromptedThisSession {
                hasPromptedThisSession = true
                _ = await SpeechTranscriber.requestPermission()
            } else {
                openSystemSettings()
            }
            scheduleRefresh(onRefresh)
        }
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
