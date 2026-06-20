import Foundation

/// Audio-Quelle für Meeting-Aufnahmen.
enum MeetingAudioSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case microphone
    case systemAudio
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .microphone: return "Mikrofon"
        case .systemAudio: return "System-Audio"
        case .both: return "Mikrofon + System"
        }
    }

    var needsMicrophone: Bool { self != .systemAudio }
    var needsSystemAudio: Bool { self != .microphone }
}

/// Ein transkribierter Abschnitt während eines Meetings.
struct MeetingChunk: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let index: Int
    let startedAt: Date
    let endedAt: Date
    var transcript: String

    init(id: UUID = UUID(), index: Int, startedAt: Date, endedAt: Date, transcript: String) {
        self.id = id
        self.index = index
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
    }
}

/// Sprach-Notiz während eines laufenden Meetings (fn+⌘).
struct MeetingVoiceNote: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    var transcript: String

    init(id: UUID = UUID(), timestamp: Date = Date(), transcript: String) {
        self.id = id
        self.timestamp = timestamp
        self.transcript = transcript
    }
}

/// Action Item aus der KI-Zusammenfassung.
struct MeetingActionItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var task: String
    var assignee: String?
    var dueDate: String?

    init(id: UUID = UUID(), task: String, assignee: String? = nil, dueDate: String? = nil) {
        self.id = id
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
    }
}

/// Strukturierte Meeting-Zusammenfassung (KI-generiert).
struct MeetingSummary: Codable, Equatable, Sendable {
    var suggestedTitle: String
    var overview: String
    var topics: [String]
    var decisions: [String]
    var actionItems: [MeetingActionItem]
    var openQuestions: [String]

    static let empty = MeetingSummary(
        suggestedTitle: "",
        overview: "",
        topics: [],
        decisions: [],
        actionItems: [],
        openQuestions: []
    )
}

/// Persistiertes Meeting inkl. Transkript und Zusammenfassung.
struct MeetingRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    let startedAt: Date
    var endedAt: Date?
    var audioSource: MeetingAudioSource
    var audioFileName: String?
    var chunks: [MeetingChunk]
    var fullTranscript: String
    var summary: MeetingSummary?
    var voiceNotes: [MeetingVoiceNote]

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        audioSource: MeetingAudioSource,
        audioFileName: String? = nil,
        chunks: [MeetingChunk] = [],
        fullTranscript: String = "",
        summary: MeetingSummary? = nil,
        voiceNotes: [MeetingVoiceNote] = []
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.audioSource = audioSource
        self.audioFileName = audioFileName
        self.chunks = chunks
        self.fullTranscript = fullTranscript
        self.summary = summary
        self.voiceNotes = voiceNotes
    }

    var isIncomplete: Bool { endedAt == nil }

    var hasRecoverableAudio: Bool {
        guard let audioFileName, !audioFileName.isEmpty else { return false }
        return true
    }

    var duration: TimeInterval {
        let end = endedAt ?? Date()
        return max(0, end.timeIntervalSince(startedAt))
    }

    var formattedDuration: String {
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    mutating func rebuildFullTranscript() {
        var parts: [String] = chunks.map(\.transcript).filter { !$0.isEmpty }
        for note in voiceNotes where !note.transcript.isEmpty {
            parts.append("[Notiz] \(note.transcript)")
        }
        fullTranscript = parts.joined(separator: "\n\n")
    }
}
