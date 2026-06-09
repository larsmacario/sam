import Foundation
import Observation
import ServiceManagement

/// Verwaltet Autostart beim Anmelden via SMAppService.
@Observable
@MainActor
final class LaunchAtLoginService {
    var isEnabled = false
    var helperText = "SAM startet nicht automatisch."
    var errorText: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status

        switch status {
        case .enabled:
            isEnabled = true
            helperText = "SAM startet beim Anmelden automatisch."
        case .notFound:
            isEnabled = false
            helperText = "SAM muss in /Applications liegen, damit der Anmeldestart zuverlässig funktioniert."
        case .requiresApproval:
            isEnabled = true
            helperText = "Noch in den Systemeinstellungen unter Anmeldeobjekte freigeben."
        case .notRegistered:
            isEnabled = false
            helperText = "SAM startet nicht automatisch."
        @unknown default:
            isEnabled = false
            helperText = "Auf diesem Mac nicht verfügbar."
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorText = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            errorText = enabled
                ? "Anmeldestart konnte nicht aktiviert werden. Lege SAM in /Applications und versuche es erneut."
                : "Anmeldestart konnte nicht deaktiviert werden. Bitte versuche es erneut."
        }
    }

    /// Aktiviert Autostart nach erfolgreichem Onboarding, wenn noch nicht registriert.
    func enableByDefaultIfNeeded() {
        refresh()
        guard !isEnabled else { return }
        setEnabled(true)
    }
}
