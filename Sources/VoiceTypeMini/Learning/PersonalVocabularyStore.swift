import Foundation

@MainActor
final class PersonalVocabularyStore {
    private let maxEntries = 500
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("VoiceTypeMini", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("personal-vocabulary.json")
    }

    func load() -> [PersonalVocabularyEntry] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        return (try? LearningJSON.decoder.decode([PersonalVocabularyEntry].self, from: data)) ?? []
    }

    func save(_ entries: [PersonalVocabularyEntry]) {
        let limitedEntries = Array(entries.deduplicatedForStore().prefix(maxEntries))
        guard let data = try? LearningJSON.encoder.encode(limitedEntries) else {
            return
        }

        try? data.write(to: fileURL, options: [.atomic])
    }

    func replace(with text: String) -> [PersonalVocabularyEntry] {
        let entries = PersonalVocabularyEntry.parseLines(text)
        save(entries)
        return Array(entries.prefix(maxEntries))
    }

    func addSuggestedPhrases(from text: String, to entries: [PersonalVocabularyEntry]) -> [PersonalVocabularyEntry] {
        let suggestions = PersonalVocabularyEntry
            .suggestedPhrases(in: text)
            .map { PersonalVocabularyEntry(phrase: $0) }

        guard !suggestions.isEmpty else {
            return entries
        }

        let nextEntries = (entries + suggestions).deduplicatedForStore()
        save(nextEntries)
        return Array(nextEntries.prefix(maxEntries))
    }
}

private extension Array where Element == PersonalVocabularyEntry {
    func deduplicatedForStore() -> [PersonalVocabularyEntry] {
        var seen = Set<String>()
        var result: [PersonalVocabularyEntry] = []

        for item in self {
            let key = item.phrase.spokenNormalized
            guard !key.isEmpty, !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(item)
        }

        return result
    }
}
