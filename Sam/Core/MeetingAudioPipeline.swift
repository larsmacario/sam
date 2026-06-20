import AVFoundation
import Foundation

/// Thread-sichere Audio-Pipeline für Meeting-Aufnahmen (Callbacks vom Audio-Thread).
final class MeetingAudioPipeline: @unchecked Sendable {
    let buffer = MeetingAudioBuffer()
    private var writer: MeetingWAVWriter?

    func configure(source: MeetingAudioSource, audioFileURL: URL) throws {
        let wavWriter = try MeetingWAVWriter(url: audioFileURL)
        writer = wavWriter
        buffer.configure(source: source, writer: wavWriter)
    }

    func reset() {
        buffer.finalizeWriter()
        writer = nil
        buffer.reset()
    }

    func finalizeRecording() {
        buffer.finalizeWriter()
        writer = nil
    }

    func handleMicrophone(_ pcmBuffer: AVAudioPCMBuffer) {
        buffer.appendMicrophone(pcmBuffer)
    }

    func handleSystem(_ pcmBuffer: AVAudioPCMBuffer) {
        buffer.appendSystem(pcmBuffer)
    }
}
