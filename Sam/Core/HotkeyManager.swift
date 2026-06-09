import AppKit
import ApplicationServices
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "HotkeyManager")

/// Globale Hotkeys via NSEvent-Monitore (wie Blitztext — zuverlässiger als reines CGEventTap).
/// - fn + ⌘ halten = Push-to-talk
/// - fn + ⌥ tippen = Modus wechseln
/// - Rechte ⌘ halten = Fallback Push-to-talk
/// - Rechte ⌥ tippen = Fallback Moduswechsel
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onToggleMode: (() -> Void)?

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?

    private var isRecordingFromFlags = false
    private var isRecordingFromKey = false
    private var isFnToggleHeld = false

    private var isRecording: Bool { isRecordingFromFlags || isRecordingFromKey }

    private init() {}

    var isAccessibilityGranted: Bool {
        AccessibilityPermissionService.currentStatus()
    }

    var isRunning: Bool {
        globalFlagsMonitor != nil
    }

    func requestAccessibilityPermission() {
        AppState.shared.requestAccessibilityPermission()
    }

    @discardableResult
    func start() -> Bool {
        stop()

        guard isAccessibilityGranted else {
            logger.warning("Accessibility-Berechtigung fehlt – HotkeyManager nicht gestartet")
            return false
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
            return event
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKeyDown(event) }
        }

        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            Task { @MainActor in self?.handleKeyUp(event) }
        }

        guard globalFlagsMonitor != nil else {
            logger.error("Globaler Event-Monitor konnte nicht erstellt werden (Accessibility?)")
            stop()
            return false
        }

        logger.info("HotkeyManager gestartet (fn+⌘ / fn+⌥, Fallback: rechte ⌘ / rechte ⌥)")
        return true
    }

    func stop() {
        [globalFlagsMonitor, localFlagsMonitor, globalKeyDownMonitor, globalKeyUpMonitor]
            .compactMap { $0 }
            .forEach { NSEvent.removeMonitor($0) }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyDownMonitor = nil
        globalKeyUpMonitor = nil
        isRecordingFromFlags = false
        isRecordingFromKey = false
        isFnToggleHeld = false
    }

    private enum KeyCode {
        static let rightCommand: UInt16 = 54
        static let rightOption: UInt16 = 61
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let fn = flags.contains(.function)
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)

        setRecordingFromFlags(fn && cmd)

        let toggleNow = fn && opt && !cmd
        if toggleNow && !isFnToggleHeld && !isRecording {
            onToggleMode?()
        }
        isFnToggleHeld = toggleNow
    }

    private func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case KeyCode.rightCommand:
            setRecordingFromKey(true)
        case KeyCode.rightOption where !event.modifierFlags.contains(.command):
            if !isRecording {
                onToggleMode?()
            }
        default:
            break
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        if event.keyCode == KeyCode.rightCommand {
            setRecordingFromKey(false)
        }
    }

    private func setRecordingFromFlags(_ pressed: Bool) {
        guard pressed != isRecordingFromFlags else { return }
        let wasRecording = isRecording
        isRecordingFromFlags = pressed
        notifyRecordingChange(wasRecording: wasRecording)
    }

    private func setRecordingFromKey(_ pressed: Bool) {
        guard pressed != isRecordingFromKey else { return }
        let wasRecording = isRecording
        isRecordingFromKey = pressed
        notifyRecordingChange(wasRecording: wasRecording)
    }

    private func notifyRecordingChange(wasRecording: Bool) {
        let nowRecording = isRecording
        if nowRecording && !wasRecording {
            onPress?()
        } else if !nowRecording && wasRecording {
            onRelease?()
        }
    }
}
