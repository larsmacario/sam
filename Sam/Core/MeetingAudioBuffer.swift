import AVFoundation

/// Sammelt und mischt 16 kHz mono Float-Samples für Meeting-Chunks.
final class MeetingAudioBuffer: @unchecked Sendable {
    private var micSamples: [Float] = []
    private var systemSamples: [Float] = []
    private var writtenMixedCount = 0
    private var audioSource: MeetingAudioSource = .microphone
    private var writer: MeetingWAVWriter?
    private let lock = NSLock()
    private let micCollector = AudioSampleCollector()
    private let systemCollector = AudioSampleCollector()

    func configure(source: MeetingAudioSource, writer: MeetingWAVWriter?) {
        lock.withLock {
            audioSource = source
            self.writer = writer
            writtenMixedCount = 0
        }
    }

    func reset() {
        lock.withLock {
            micSamples.removeAll()
            systemSamples.removeAll()
            writtenMixedCount = 0
            writer = nil
            audioSource = .microphone
        }
        micCollector.reset()
        systemCollector.reset()
    }

    func finalizeWriter() {
        lock.withLock {
            persistPendingToDiskLocked()
            writer?.finalize()
            writer = nil
        }
    }

    func appendMicrophone(_ buffer: AVAudioPCMBuffer) {
        micCollector.append(buffer)
        flushMicCollectorIfNeeded()
    }

    func appendSystem(_ buffer: AVAudioPCMBuffer) {
        systemCollector.append(buffer)
        flushSystemCollectorIfNeeded()
    }

    private func flushMicCollectorIfNeeded() {
        let batch = micCollector.drain()
        guard !batch.isEmpty else { return }
        lock.withLock {
            micSamples.append(contentsOf: batch)
            persistMicBatchLocked(batch)
            persistMixedToDiskLocked()
        }
    }

    private func flushSystemCollectorIfNeeded() {
        let batch = systemCollector.drain()
        guard !batch.isEmpty else { return }
        lock.withLock {
            systemSamples.append(contentsOf: batch)
            persistSystemBatchLocked(batch)
            persistMixedToDiskLocked()
        }
    }

    var pendingSampleCount: Int {
        flushMicCollectorIfNeeded()
        flushSystemCollectorIfNeeded()
        return lock.withLock { max(micSamples.count, systemSamples.count) }
    }

    /// Entnimmt bis zu `maxSamples` aus der gewählten Quelle.
    func drainChunk(maxSamples: Int, source: MeetingAudioSource) -> [Float] {
        flushMicCollectorIfNeeded()
        flushSystemCollectorIfNeeded()
        return lock.withLock {
            switch source {
            case .both:
                return drainMixed(maxSamples: maxSamples)
            case .microphone:
                return drain(from: &micSamples, maxSamples: maxSamples)
            case .systemAudio:
                return drain(from: &systemSamples, maxSamples: maxSamples)
            }
        }
    }

    /// Entnimmt alle verbleibenden Samples.
    func drainAll(source: MeetingAudioSource) -> [Float] {
        flushMicCollectorIfNeeded()
        flushSystemCollectorIfNeeded()
        return lock.withLock {
            persistPendingToDiskLocked()
            switch source {
            case .both:
                let count = max(micSamples.count, systemSamples.count)
                guard count > 0 else { return [] }
                return drainMixed(maxSamples: count)
            case .microphone:
                let all = micSamples
                micSamples.removeAll()
                return all
            case .systemAudio:
                let all = systemSamples
                systemSamples.removeAll()
                return all
            }
        }
    }

    // MARK: - Disk persistence

    private func persistMicBatchLocked(_ batch: [Float]) {
        guard audioSource == .microphone else { return }
        writer?.append(samples: batch)
    }

    private func persistSystemBatchLocked(_ batch: [Float]) {
        guard audioSource == .systemAudio else { return }
        writer?.append(samples: batch)
    }

    private func persistMixedToDiskLocked() {
        guard audioSource == .both else { return }
        let mixable = min(micSamples.count, systemSamples.count) - writtenMixedCount
        guard mixable > 0, let writer else { return }

        var mixed = [Float]()
        mixed.reserveCapacity(mixable)
        for index in writtenMixedCount..<(writtenMixedCount + mixable) {
            let mic = micSamples[index]
            let sys = systemSamples[index]
            mixed.append(clamp(mic * 0.5 + sys * 0.5))
        }
        writer.append(samples: mixed)
        writtenMixedCount += mixable
    }

    private func persistPendingToDiskLocked() {
        switch audioSource {
        case .both:
            persistMixedToDiskLocked()
        case .microphone, .systemAudio:
            break
        }
    }

    private func drain(from samples: inout [Float], maxSamples: Int) -> [Float] {
        let count = min(maxSamples, samples.count)
        guard count > 0 else { return [] }
        let chunk = Array(samples.prefix(count))
        samples.removeFirst(count)
        return chunk
    }

    private func drainMixed(maxSamples: Int) -> [Float] {
        let count = min(maxSamples, max(micSamples.count, systemSamples.count))
        guard count > 0 else { return [] }

        var mixed = [Float]()
        mixed.reserveCapacity(count)
        for i in 0..<count {
            let mic = i < micSamples.count ? micSamples[i] : 0
            let sys = i < systemSamples.count ? systemSamples[i] : 0
            mixed.append(clamp(mic * 0.5 + sys * 0.5))
        }
        micSamples.removeFirst(min(count, micSamples.count))
        systemSamples.removeFirst(min(count, systemSamples.count))
        writtenMixedCount = max(0, writtenMixedCount - count)
        return mixed
    }

    private func clamp(_ value: Float) -> Float {
        max(-1, min(1, value))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
