import Foundation

@MainActor
final class TranscriptHistoryStore {
    private let maxItems = 10
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("VoiceTypeMini", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("transcript-history.json")
    }

    func load() -> [TranscriptHistoryItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        return (try? JSONDecoder().decode([TranscriptHistoryItem].self, from: data)) ?? []
    }

    func save(_ items: [TranscriptHistoryItem]) {
        guard let data = try? JSONEncoder.voiceTypeMini.encode(Array(items.prefix(maxItems))) else {
            return
        }

        try? data.write(to: fileURL, options: [.atomic])
    }

    func add(_ item: TranscriptHistoryItem, to items: [TranscriptHistoryItem]) -> [TranscriptHistoryItem] {
        var nextItems = items
        nextItems.removeAll { $0.text == item.text }
        nextItems.insert(item, at: 0)
        nextItems = Array(nextItems.prefix(maxItems))
        save(nextItems)
        return nextItems
    }

    func clear() {
        save([])
    }
}

private extension JSONEncoder {
    static var voiceTypeMini: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
