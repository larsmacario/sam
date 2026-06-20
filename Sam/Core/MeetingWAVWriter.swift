import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "MeetingWAVWriter")

/// Streamt 16 kHz mono PCM als WAV auf Platte (Header wird beim Schließen finalisiert).
final class MeetingWAVWriter: @unchecked Sendable {
    static let headerSize = 44
    private static let sampleRate = Int(AudioSampleCollector.targetSampleRate)

    private let url: URL
    private let handle: FileHandle
    private var sampleCount = 0
    private let lock = NSLock()
    private var isClosed = false

    init(url: URL) throws {
        self.url = url
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: Self.placeholderHeader())
        handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: UInt64(Self.headerSize))
        logger.info("Meeting-WAV gestartet: \(url.lastPathComponent, privacy: .public)")
    }

    func append(samples: [Float]) {
        guard !samples.isEmpty else { return }
        lock.withLock {
            guard !isClosed else { return }
            var data = Data(capacity: samples.count * 2)
            for sample in samples {
                let clamped = max(-1, min(1, sample))
                var int16 = Int16(clamped * 32_767).littleEndian
                withUnsafeBytes(of: &int16) { data.append(contentsOf: $0) }
            }
            do {
                try handle.write(contentsOf: data)
                sampleCount += samples.count
            } catch {
                logger.error("WAV-Schreiben fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func finalize() {
        lock.withLock {
            guard !isClosed else { return }
            isClosed = true
            do {
                let header = Self.finalHeader(sampleCount: sampleCount)
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: header)
                try handle.close()
                logger.info("Meeting-WAV finalisiert: \(self.sampleCount) Samples")
            } catch {
                logger.error("WAV-Finalisierung fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func abort() {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true
        try? handle.close()
    }

    // MARK: - WAV Header

    private static func placeholderHeader() -> Data {
        finalHeader(sampleCount: 0)
    }

    private static func finalHeader(sampleCount: Int) -> Data {
        let numChannels = 1
        let bitsPerSample = 16
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = sampleCount * 2

        var data = Data(capacity: headerSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32LE(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(UInt16(numChannels))
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32LE(UInt32(dataSize))
        return data
    }

    /// Liest 16 kHz mono Float-Samples aus einer SAM-Meeting-WAV-Datei.
    static func readSamples(from url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        guard data.count > headerSize else { return [] }

        let riff = String(data: data[0..<4], encoding: .ascii)
        let wave = String(data: data[8..<12], encoding: .ascii)
        guard riff == "RIFF", wave == "WAVE" else {
            throw MeetingWAVReaderError.invalidFormat
        }

        var offset = 12
        var sampleRate = Self.sampleRate
        var bitsPerSample = 16
        var dataOffset = 0
        var dataSize = 0

        while offset + 8 <= data.count {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = Int(data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self).littleEndian
            })
            let chunkStart = offset + 8
            if chunkID == "fmt ", chunkStart + 16 <= data.count {
                sampleRate = Int(data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: chunkStart + 4, as: UInt32.self).littleEndian
                })
                bitsPerSample = Int(data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: chunkStart + 14, as: UInt16.self).littleEndian
                })
            } else if chunkID == "data" {
                dataOffset = chunkStart
                dataSize = min(chunkSize, data.count - chunkStart)
                break
            }
            offset = chunkStart + max(chunkSize, 0)
        }

        guard dataOffset > 0, bitsPerSample == 16 else {
            throw MeetingWAVReaderError.unsupportedFormat
        }

        if dataSize == 0, data.count > headerSize {
            dataOffset = headerSize
            dataSize = data.count - headerSize
        }

        guard dataSize > 0 else { return [] }
        guard sampleRate == Self.sampleRate else {
            throw MeetingWAVReaderError.unsupportedSampleRate
        }

        let sampleCount = dataSize / 2
        var samples = [Float]()
        samples.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            let byteIndex = dataOffset + index * 2
            let int16 = Int16(littleEndian: data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: byteIndex, as: Int16.self)
            })
            samples.append(Float(int16) / 32_767)
        }
        return samples
    }
}

enum MeetingWAVReaderError: LocalizedError {
    case invalidFormat
    case unsupportedFormat
    case unsupportedSampleRate

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Ungültiges WAV-Format."
        case .unsupportedFormat: return "WAV-Format wird nicht unterstützt."
        case .unsupportedSampleRate: return "Nur 16 kHz WAV wird unterstützt."
        }
    }
}

private extension NSLock {
    func withLock(_ body: () -> Void) {
        lock()
        defer { unlock() }
        body()
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
}
