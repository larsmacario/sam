import AppKit
import ApplicationServices

/// Accessibility-Berechtigung für globale Hotkeys und Text-Einfügen.
@MainActor
enum AccessibilityPermissionService {
    private static var hasPromptedThisSession = false

    nonisolated static func currentStatus() -> Bool {
        AXIsProcessTrusted()
    }

    static func isTrusted(promptIfNeeded: Bool) -> Bool {
        let shouldPrompt = promptIfNeeded && !hasPromptedThisSession
        if shouldPrompt {
            hasPromptedThisSession = true
        }
        return checkTrusted(prompt: shouldPrompt)
    }

    /// Zeigt den macOS-Systemdialog für Bedienungshilfen (einmal pro Session).
    static func requestPermissionPrompt() -> Bool {
        hasPromptedThisSession = true
        return checkTrusted(prompt: true)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Systemdialog, danach Bedienungshilfen — mit Polling bis Freigabe erteilt ist.
    static func requestPermission(onRefresh: (@MainActor () -> Void)? = nil) {
        let trusted = requestPermissionPrompt()
        if !trusted {
            openSystemSettings()
        }
        scheduleRefresh(onRefresh)
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

    nonisolated private static func checkTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
