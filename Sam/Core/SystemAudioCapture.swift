import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "SystemAudioCapture")

enum SystemAudioCaptureError: LocalizedError {
    case noDisplay
    case streamStartFailed(Error)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "Kein Bildschirm für System-Audio gefunden."
        case .streamStartFailed(let error):
            return "System-Audio konnte nicht gestartet werden: \(error.localizedDescription)"
        case .notAuthorized:
            return "Bildschirmaufnahme-Berechtigung fehlt für System-Audio."
        }
    }
}

/// Erfasst System-Audio über ScreenCaptureKit (Zoom, Teams, Meet …).
final class SystemAudioCapture: NSObject, @unchecked Sendable {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "de.larsmacario.sam.system-audio")
    private let stateLock = NSLock()

    private var isCapturing = false
    private var shouldRestart = false
    private var restartCount = 0
    private(set) var lastBufferAt: Date?

    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?

    func start() async throws {
        stateLock.withLock {
            shouldRestart = true
            isCapturing = true
        }
        try await startStream()
    }

    func stop() async {
        stateLock.withLock {
            shouldRestart = false
            isCapturing = false
        }
        await tearDownStream()
        onBuffer = nil
        stateLock.withLock { lastBufferAt = nil }
        logger.info("System-Audio-Aufnahme gestoppt")
    }

    /// Neustart bei Stream-Fehler oder Watchdog.
    func restartIfNeeded(reason: String) async {
        let shouldProceed: Bool = stateLock.withLock {
            guard isCapturing, shouldRestart else { return false }
            restartCount += 1
            logger.warning("System-Audio-Neustart (#\(self.restartCount)): \(reason, privacy: .public)")
            return true
        }
        guard shouldProceed else { return }

        await tearDownStream()
        do {
            try await startStream()
            stateLock.withLock { lastBufferAt = Date() }
        } catch {
            logger.error("System-Audio-Neustart fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    var secondsSinceLastBuffer: TimeInterval? {
        stateLock.withLock {
            guard isCapturing, let lastBufferAt else { return nil }
            return Date().timeIntervalSince(lastBufferAt)
        }
    }

    var isActive: Bool {
        stateLock.withLock { isCapturing }
    }

    // MARK: - Private

    private func startStream() async throws {
        guard ScreenCapturePermissionService.hasPermission else {
            throw SystemAudioCaptureError.notAuthorized
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: SCStreamOutputType.audio, sampleHandlerQueue: queue)

        do {
            try await stream.startCapture()
            self.stream = stream
            stateLock.withLock { lastBufferAt = Date() }
            logger.info("System-Audio-Aufnahme gestartet")
        } catch {
            throw SystemAudioCaptureError.streamStartFailed(error)
        }
    }

    private func tearDownStream() async {
        if let stream {
            do {
                try await stream.stopCapture()
            } catch {
                logger.error("System-Audio stop fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
        stream = nil
    }
}

extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("System-Audio-Stream gestoppt: \(error.localizedDescription, privacy: .public)")
        Task {
            await restartIfNeeded(reason: "didStopWithError: \(error.localizedDescription)")
        }
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferGetNumSamples(sampleBuffer) > 0 else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        let format = AVAudioFormat(streamDescription: asbd)
        guard let format else { return }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard status == noErr else { return }

        stateLock.withLock { lastBufferAt = Date() }
        onBuffer?(pcmBuffer)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
