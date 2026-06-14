import Foundation

@MainActor
final class CorrectionLearningStore {
    private let maxExamples = 250
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("VoiceTypeMini", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("correction-examples.json")
    }

    func load() -> [CorrectionExample] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        return (try? LearningJSON.decoder.decode([CorrectionExample].self, from: data)) ?? []
    }

    func save(_ examples: [CorrectionExample]) {
        guard let data = try? LearningJSON.encoder.encode(Array(examples.prefix(maxExamples))) else {
            return
        }

        try? data.write(to: fileURL, options: [.atomic])
    }

    func add(_ example: CorrectionExample, to examples: [CorrectionExample]) -> [CorrectionExample] {
        var nextExamples = examples
        nextExamples.removeAll {
            $0.originalText.isSameSpokenPhrase(as: example.originalText)
                && $0.correctedText.isSameSpokenPhrase(as: example.correctedText)
        }
        nextExamples.insert(example, at: 0)
        nextExamples = Array(nextExamples.prefix(maxExamples))
        save(nextExamples)
        return nextExamples
    }

    func clear() {
        save([])
    }
}
