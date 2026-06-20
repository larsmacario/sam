import AVFoundation
import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "MeetingSession")

enum MeetingSessionStatus: String, Sendable {
    case idle
    case recording
    case transcribing
    case summarizing
    case recovering
}

enum MeetingSessionError: LocalizedError {
    case alreadyActive
    case notActive
    case microphonePermissionDenied
    case screenCapturePermissionDenied
    case audioStartFailed(String)
    case recoveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyActive: return "Es läuft bereits ein Meeting."
        case .notActive: return "Kein aktives Meeting."
        case .microphonePermissionDenied: return "Mikrofon-Berechtigung fehlt."
        case .screenCapturePermissionDenied: return "Bildschirmaufnahme-Berechtigung fehlt für System-Audio."
        case .audioStartFailed(let message): return message
        case .recoveryFailed(let message): return message
        }
    }
}

/// Verwaltet laufende Meeting-Aufnahmen, Chunk-Transkription und Persistenz.
@MainActor
final class MeetingSessionController: ObservableObject {
    static let shared = MeetingSessionController()

    private static let staleBufferThresholdSeconds: TimeInterval = 8
    private static let captureWarmupSeconds: TimeInterval = 5

    @Published private(set) var isActive = false
    @Published private(set) var status: MeetingSessionStatus = .idle
    @Published private(set) var startedAt: Date?
    @Published private(set) var liveTranscript = ""
    @Published private(set) var lastCompletedRecord: MeetingRecord?
    @Published var hasAcknowledgedRecordingNotice = false

    private let settings = SettingsStore.shared
    private let store = MeetingStore.shared
    private let overlay = OverlayWindowController.shared
    private let transcriptionQueue = MeetingTranscriptionQueue.shared

    private var record: MeetingRecord?
    private var chunkIndex = 0
    private var chunkStartedAt = Date()
    private var useOnlineFallback = false
    private var captureStartedAt: Date?

    private let micRecorder = ContinuousAudioRecorder()
    private let systemCapture = SystemAudioCapture()
    private let audioPipeline = MeetingAudioPipeline()

    private var chunkMonitorTask: Task<Void, Never>?
    private var pendingTranscriptionCount = 0

    private init() {}

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    func start(title: String? = nil) async throws {
        guard !isActive else { throw MeetingSessionError.alreadyActive }

        let audioSource = settings.meetingAudioSource
        if audioSource.needsMicrophone, !AudioRecorder.hasPermission {
            throw MeetingSessionError.microphonePermissionDenied
        }
        if audioSource.needsSystemAudio, !ScreenCapturePermissionService.hasPermission {
            throw MeetingSessionError.screenCapturePermissionDenied
        }

        let meetingTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? title!.trimmingCharacters(in: .whitespacesAndNewlines)
            : defaultTitle()

        var newRecord = MeetingRecord(title: meetingTitle, audioSource: audioSource)
        let audioFileName = MeetingStore.defaultAudioFileName(for: newRecord.id)
        newRecord.audioFileName = audioFileName
        let audioURL = store.audioFileURL(meetingID: newRecord.id, fileName: audioFileName)

        record = newRecord
        chunkIndex = newRecord.chunks.count
        chunkStartedAt = Date()
        useOnlineFallback = false
        liveTranscript = newRecord.fullTranscript
        isActive = true
        status = .recording
        startedAt = Date()
        captureStartedAt = Date()
        audioPipeline.reset()

        do {
            try audioPipeline.configure(source: audioSource, audioFileURL: audioURL)
        } catch {
            record = nil
            isActive = false
            status = .idle
            startedAt = nil
            throw MeetingSessionError.audioStartFailed(error.localizedDescription)
        }

        store.save(newRecord)
        overlay.showMeetingRecording()

        do {
            if audioSource.needsMicrophone {
                micRecorder.onBuffer = { [pipeline = audioPipeline] buffer in
                    pipeline.handleMicrophone(buffer)
                }
                try micRecorder.start()
            }
            if audioSource.needsSystemAudio {
                systemCapture.onBuffer = { [pipeline = audioPipeline] buffer in
                    pipeline.handleSystem(buffer)
                }
                try await systemCapture.start()
            }
        } catch {
            audioPipeline.reset()
            if let failedRecord = record {
                store.delete(id: failedRecord.id)
            }
            isActive = false
            status = .idle
            startedAt = nil
            captureStartedAt = nil
            record = nil
            overlay.revertMeetingToIdle()
            throw MeetingSessionError.audioStartFailed(error.localizedDescription)
        }

        startChunkMonitor()
        logger.info("Meeting gestartet: \(meetingTitle, privacy: .public)")
    }

    func stop() async {
        guard isActive else { return }

        chunkMonitorTask?.cancel()
        chunkMonitorTask = nil
        status = .transcribing
        overlay.updateMeetingStatus(.transcribing)

        micRecorder.stop()
        await systemCapture.stop()
        audioPipeline.finalizeRecording()

        await processFinalChunk()
        await waitForPendingTranscriptions()

        guard var current = record else { return }
        current.endedAt = Date()
        current.rebuildFullTranscript()

        if settings.isActiveProviderConfigured, !current.fullTranscript.isEmpty {
            status = .summarizing
            overlay.updateMeetingStatus(.summarizing)
            do {
                let client = LLMClientFactory.make(for: settings.selectedProvider)
                let summary = try await client.summarizeMeeting(
                    transcript: current.fullTranscript,
                    modelID: settings.currentModelID
                )
                current.summary = summary
                if current.title.hasPrefix("Meeting ") || current.title == defaultTitle() {
                    let suggested = summary.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !suggested.isEmpty { current.title = suggested }
                }
            } catch {
                logger.error("Meeting-Summary fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }

        store.save(current)
        lastCompletedRecord = current
        isActive = false
        status = .idle
        startedAt = nil
        captureStartedAt = nil
        record = nil
        audioPipeline.reset()

        if let summary = current.summary, !summary.overview.isEmpty {
            overlay.showMeetingSummary(record: current)
        } else if !current.fullTranscript.isEmpty {
            overlay.showMeetingSummary(record: current)
        }

        logger.info("Meeting beendet: Länge=\(current.fullTranscript.count)")
    }

    /// Stellt ein abgebrochenes Meeting aus der WAV-Datei wieder her und transkribiert neu.
    func recoverIncompleteMeeting(_ incomplete: MeetingRecord) async throws {
        guard !isActive else { throw MeetingSessionError.alreadyActive }
        guard let audioURL = store.audioFileURL(for: incomplete), store.audioFileExists(for: incomplete) else {
            throw MeetingSessionError.recoveryFailed("Audiodatei nicht gefunden.")
        }

        status = .recovering
        var current = incomplete
        current.chunks = []
        current.fullTranscript = ""
        current.summary = nil
        record = current
        chunkIndex = 0
        chunkStartedAt = current.startedAt
        useOnlineFallback = true
        liveTranscript = ""
        pendingTranscriptionCount = 0

        do {
            let samples = try MeetingWAVWriter.readSamples(from: audioURL)
            guard !samples.isEmpty else {
                throw MeetingSessionError.recoveryFailed("Audiodatei ist leer.")
            }

            let threshold = Int(settings.meetingChunkIntervalSeconds * AudioSampleCollector.targetSampleRate)
            var offset = 0
            while offset < samples.count {
                let end = min(offset + threshold, samples.count)
                let chunkSamples = Array(samples[offset..<end])
                offset = end
                let isFinal = offset >= samples.count
                await transcribeChunk(samples: chunkSamples, isFinal: isFinal)
            }

            await waitForPendingTranscriptions()

            guard var recovered = record else {
                throw MeetingSessionError.recoveryFailed("Wiederherstellung fehlgeschlagen.")
            }
            recovered.endedAt = Date()
            recovered.rebuildFullTranscript()

            if settings.isActiveProviderConfigured, !recovered.fullTranscript.isEmpty {
                status = .summarizing
                do {
                    let client = LLMClientFactory.make(for: settings.selectedProvider)
                    let summary = try await client.summarizeMeeting(
                        transcript: recovered.fullTranscript,
                        modelID: settings.currentModelID
                    )
                    recovered.summary = summary
                } catch {
                    logger.error("Recovery-Summary fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                }
            }

            store.save(recovered)
            lastCompletedRecord = recovered
            record = nil
            status = .idle
            liveTranscript = recovered.fullTranscript

            if !recovered.fullTranscript.isEmpty {
                overlay.showMeetingSummary(record: recovered)
            }
            logger.info("Meeting wiederhergestellt: \(recovered.fullTranscript.count) Zeichen")
        } catch let error as MeetingSessionError {
            record = nil
            status = .idle
            throw error
        } catch {
            record = nil
            status = .idle
            throw MeetingSessionError.recoveryFailed(error.localizedDescription)
        }
    }

    func discardIncompleteMeeting(_ incomplete: MeetingRecord) {
        store.delete(id: incomplete.id)
    }

    // MARK: - Private

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Meeting \(formatter.string(from: Date()))"
    }

    private func startChunkMonitor() {
        chunkMonitorTask?.cancel()
        chunkMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.monitorCaptureHealth()
                await self?.checkChunkThreshold()
            }
        }
    }

    private func monitorCaptureHealth() async {
        guard isActive, let source = record?.audioSource else { return }
        guard let captureStartedAt else { return }
        let warmupElapsed = Date().timeIntervalSince(captureStartedAt)
        guard warmupElapsed >= Self.captureWarmupSeconds else { return }

        if source.needsMicrophone, micRecorder.isActive {
            if let stale = micRecorder.secondsSinceLastBuffer, stale >= Self.staleBufferThresholdSeconds {
                micRecorder.restartIfNeeded(reason: "Watchdog: keine Mikrofon-Buffer seit \(Int(stale))s")
            }
        }

        if source.needsSystemAudio, systemCapture.isActive {
            if let stale = systemCapture.secondsSinceLastBuffer, stale >= Self.staleBufferThresholdSeconds {
                await systemCapture.restartIfNeeded(reason: "Watchdog: keine System-Buffer seit \(Int(stale))s")
            }
        }
    }

    private func checkChunkThreshold() {
        guard isActive, let source = record?.audioSource else { return }
        let threshold = Int(settings.meetingChunkIntervalSeconds * AudioSampleCollector.targetSampleRate)
        guard audioPipeline.buffer.pendingSampleCount >= threshold else { return }
        let samples = audioPipeline.buffer.drainChunk(maxSamples: threshold, source: source)
        guard !samples.isEmpty else { return }
        enqueueChunkTranscription(samples: samples, isFinal: false)
    }

    private func processFinalChunk() async {
        guard let source = record?.audioSource else { return }
        let samples = audioPipeline.buffer.drainAll(source: source)
        guard !samples.isEmpty else { return }
        await transcribeChunk(samples: samples, isFinal: true)
    }

    private func enqueueChunkTranscription(samples: [Float], isFinal: Bool) {
        pendingTranscriptionCount += 1
        Task { @MainActor [weak self] in
            defer { self?.pendingTranscriptionCount = max(0, (self?.pendingTranscriptionCount ?? 1) - 1) }
            await self?.transcribeChunk(samples: samples, isFinal: isFinal)
        }
    }

    private func waitForPendingTranscriptions() async {
        while pendingTranscriptionCount > 0 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func transcribeChunk(samples: [Float], isFinal: Bool) async {
        guard var current = record else { return }

        if !isFinal, status == .recording {
            overlay.updateMeetingStatus(.transcribing)
        }

        let elapsedMinutes = elapsed / 60
        if elapsedMinutes >= Double(settings.meetingOnlineFallbackAfterMinutes) {
            useOnlineFallback = true
        }

        do {
            let text = try await transcriptionQueue.transcribe(
                samples: samples,
                localModel: settings.whisperLocalModel,
                onlineModel: settings.whisperOnlineModel,
                language: settings.transcriptionLanguage,
                forceOnline: useOnlineFallback
            )
            guard !text.isEmpty else {
                if isFinal { restoreRecordingStatusIfNeeded() }
                return
            }

            let chunk = MeetingChunk(
                index: chunkIndex,
                startedAt: chunkStartedAt,
                endedAt: Date(),
                transcript: text
            )
            chunkIndex += 1
            chunkStartedAt = Date()
            current.chunks.append(chunk)
            record = current
            current.rebuildFullTranscript()
            liveTranscript = current.fullTranscript
            overlay.updateMeetingTranscript(liveTranscript)
            store.save(current)
        } catch {
            logger.error("Chunk-Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        restoreRecordingStatusIfNeeded()
    }

    private func restoreRecordingStatusIfNeeded() {
        guard isActive, status != .recording else { return }
        if status == .transcribing, record != nil {
            status = .recording
            overlay.updateMeetingStatus(.recording)
        }
    }
}
