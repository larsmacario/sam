import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "MeetingStore")

/// Persistiert Meeting-Daten als JSON unter Application Support.
@MainActor
final class MeetingStore: ObservableObject {
    static let shared = MeetingStore()

    @Published private(set) var meetings: [MeetingRecord] = []
    @Published private(set) var incompleteMeetings: [MeetingRecord] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        reload()
    }

    static var defaultStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SAM/meetings", isDirectory: true)
    }

    var storageDirectory: URL {
        SettingsStore.shared.meetingStorageDirectoryURL
    }

    private var meetingsDirectory: URL { storageDirectory }

    private func fileURL(for id: UUID) -> URL {
        meetingsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    func audioFileURL(for record: MeetingRecord) -> URL? {
        guard let name = record.audioFileName, !name.isEmpty else { return nil }
        return meetingsDirectory.appendingPathComponent(name)
    }

    func audioFileURL(meetingID: UUID, fileName: String) -> URL {
        meetingsDirectory.appendingPathComponent(fileName)
    }

    static func defaultAudioFileName(for id: UUID) -> String {
        "\(id.uuidString).wav"
    }

    func reload() {
        do {
            try fileManager.createDirectory(at: meetingsDirectory, withIntermediateDirectories: true)
            let files = try fileManager.contentsOfDirectory(at: meetingsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            var loaded: [MeetingRecord] = []
            var incomplete: [MeetingRecord] = []
            for file in files {
                if let data = try? Data(contentsOf: file),
                   let record = try? decoder.decode(MeetingRecord.self, from: data) {
                    loaded.append(record)
                    if record.isIncomplete, audioFileExists(for: record) {
                        incomplete.append(record)
                    }
                }
            }
            meetings = loaded.sorted { $0.startedAt > $1.startedAt }
            incompleteMeetings = incomplete.sorted { $0.startedAt > $1.startedAt }
        } catch {
            logger.error("Meetings laden fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            meetings = []
            incompleteMeetings = []
        }
    }

    func save(_ record: MeetingRecord) {
        do {
            try fileManager.createDirectory(at: meetingsDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(record)
            try data.write(to: fileURL(for: record.id), options: .atomic)
            if let index = meetings.firstIndex(where: { $0.id == record.id }) {
                meetings[index] = record
            } else {
                meetings.insert(record, at: 0)
            }
            meetings.sort { $0.startedAt > $1.startedAt }

            if record.isIncomplete, audioFileExists(for: record) {
                if let index = incompleteMeetings.firstIndex(where: { $0.id == record.id }) {
                    incompleteMeetings[index] = record
                } else {
                    incompleteMeetings.insert(record, at: 0)
                }
            } else {
                incompleteMeetings.removeAll { $0.id == record.id }
            }
            incompleteMeetings.sort { $0.startedAt > $1.startedAt }
        } catch {
            logger.error("Meeting speichern fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    func load(id: UUID) -> MeetingRecord? {
        meetings.first(where: { $0.id == id })
    }

    func delete(id: UUID) {
        do {
            if let record = load(id: id), let audioURL = audioFileURL(for: record),
               fileManager.fileExists(atPath: audioURL.path) {
                try fileManager.removeItem(at: audioURL)
            }
            let url = fileURL(for: id)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            meetings.removeAll { $0.id == id }
            incompleteMeetings.removeAll { $0.id == id }
        } catch {
            logger.error("Meeting löschen fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    func audioFileExists(for record: MeetingRecord) -> Bool {
        guard let url = audioFileURL(for: record) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }
}
