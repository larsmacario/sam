import AVFoundation
import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "ContinuousAudioRecorder")

/// Dauerhafte Mikrofon-Aufnahme für Meeting-Sessions (unabhängig von Push-to-talk).
final class ContinuousAudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var isRecording = false
    private var configurationObserver: NSObjectProtocol?

    private(set) var lastBufferAt: Date?
    private var restartCount = 0

    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    func start() throws {
        try lock.withLock {
            guard !isRecording else { return }
            guard AudioRecorder.hasPermission else {
                throw AudioRecorderError.permissionDenied
            }
            try installTapAndStartEngine()
            registerConfigurationObserver()
            isRecording = true
            lastBufferAt = Date()
            logger.info("Dauer-Aufnahme gestartet")
        }
    }

    func stop() {
        lock.withLock {
            guard isRecording else { return }
            teardownTapAndEngine()
            if let configurationObserver {
                NotificationCenter.default.removeObserver(configurationObserver)
                self.configurationObserver = nil
            }
            isRecording = false
            lastBufferAt = nil
            onBuffer = nil
            logger.info("Dauer-Aufnahme gestoppt")
        }
    }

    /// Neustart bei Konfigurationswechsel oder Watchdog – Session bleibt aktiv.
    func restartIfNeeded(reason: String) {
        lock.withLock {
            guard isRecording else { return }
            restartCount += 1
            logger.warning("Mikrofon-Neustart (#\(self.restartCount)): \(reason, privacy: .public)")
            teardownTapAndEngine()
            do {
                try installTapAndStartEngine()
                lastBufferAt = Date()
            } catch {
                logger.error("Mikrofon-Neustart fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    var secondsSinceLastBuffer: TimeInterval? {
        lock.withLock {
            guard isRecording, let lastBufferAt else { return nil }
            return Date().timeIntervalSince(lastBufferAt)
        }
    }

    var isActive: Bool {
        lock.withLock { isRecording }
    }

    // MARK: - Private

    private func registerConfigurationObserver() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.restartIfNeeded(reason: "AVAudioEngineConfigurationChange")
        }
    }

    private func installTapAndStartEngine() throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineStartFailed(error)
        }
    }

    private func teardownTapAndEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            lastBufferAt = Date()
        }
        onBuffer?(buffer)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
