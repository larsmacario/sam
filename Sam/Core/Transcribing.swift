import AVFoundation

/// Einheitliche Schnittstelle für alle STT-Engines.
/// Apple streamt Live-Text via `onPartial`; Whisper liefert das Ergebnis erst in `finish()`.
/// Implementierungen sind @unchecked Sendable (eigene Thread-Sicherheit).
protocol Transcribing: AnyObject, Sendable {
    var onPartial: (@Sendable (String) -> Void)? { get set }
    func start() throws
    func append(_ buffer: AVAudioPCMBuffer)
    func finish() async throws -> String
}

/// Reicht thread-konfinierte non-Sendable Werte über @Sendable-Closure-Grenzen.
private final class Ref<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

/// Sammelt eingehende PCM-Buffer und rechnet sie auf 16 kHz mono Float um (Whisper-Eingabeformat).
final class AudioSampleCollector: @unchecked Sendable {
    static let targetSampleRate: Double = 16_000

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?
    private var samples: [Float] = []
    private let lock = NSLock()

    func reset() {
        lock.withLock { samples.removeAll() }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let inFormat = buffer.format
        if converter == nil || sourceFormat != inFormat {
            converter = AVAudioConverter(from: inFormat, to: targetFormat)
            sourceFormat = inFormat
        }
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / inFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard capacity > 0,
              let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        // Boxen, da der InputBlock @Sendable ist; der Converter ruft ihn synchron auf.
        let bufferRef = Ref(buffer)
        let fedRef = Ref(false)
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if fedRef.value {
                outStatus.pointee = .noDataNow
                return nil
            }
            fedRef.value = true
            outStatus.pointee = .haveData
            return bufferRef.value
        }

        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
        guard status != .error, let channelData = outBuffer.floatChannelData else { return }

        let frames = Int(outBuffer.frameLength)
        let ptr = channelData[0]
        lock.withLock {
            samples.append(contentsOf: UnsafeBufferPointer(start: ptr, count: frames))
        }
    }

    /// Gibt die gesammelten Samples zurück und leert den Puffer.
    func drain() -> [Float] {
        lock.withLock {
            let result = samples
            samples.removeAll()
            return result
        }
    }
}

/// Kodiert 16 kHz mono Float-Samples als 16-bit-PCM-WAV (für die OpenAI-Transkriptions-API).
enum WAVEncoder {
    static func encode(samples: [Float], sampleRate: Int = 16_000) -> Data {
        let numChannels = 1
        let bitsPerSample = 16
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = samples.count * 2

        var data = Data(capacity: 44 + dataSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32LE(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32LE(16)
        data.appendUInt16LE(1) // PCM
        data.appendUInt16LE(UInt16(numChannels))
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32LE(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            data.appendInt16LE(Int16(clamped * 32_767))
        }
        return data
    }
}

private extension Data {
    mutating func appendUInt32LE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendUInt16LE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendInt16LE(_ value: Int16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
