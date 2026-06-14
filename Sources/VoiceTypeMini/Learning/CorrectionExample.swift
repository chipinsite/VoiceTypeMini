import Foundation

struct CorrectionExample: Codable, Identifiable, Equatable {
    let id: UUID
    let originalText: String
    let correctedText: String
    let backend: String
    let model: String?
    let targetApplication: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        originalText: String,
        correctedText: String,
        backend: String,
        model: String?,
        targetApplication: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.correctedText = correctedText
        self.backend = backend
        self.model = model
        self.targetApplication = targetApplication
        self.createdAt = createdAt
    }

    var replacementCandidate: LearnedReplacement? {
        let originalWords = originalText.transcriptWords
        let correctedWords = correctedText.transcriptWords

        guard !originalWords.isEmpty, !correctedWords.isEmpty else {
            return nil
        }

        var prefixCount = 0
        while prefixCount < originalWords.count,
              prefixCount < correctedWords.count,
              originalWords[prefixCount].isSameSpokenPhrase(as: correctedWords[prefixCount]) {
            prefixCount += 1
        }

        var suffixCount = 0
        while suffixCount + prefixCount < originalWords.count,
              suffixCount + prefixCount < correctedWords.count,
              originalWords[originalWords.count - 1 - suffixCount]
                .isSameSpokenPhrase(as: correctedWords[correctedWords.count - 1 - suffixCount]) {
            suffixCount += 1
        }

        let originalChanged = Array(originalWords[prefixCount..<(originalWords.count - suffixCount)])
        let correctedChanged = Array(correctedWords[prefixCount..<(correctedWords.count - suffixCount)])

        guard !originalChanged.isEmpty, !correctedChanged.isEmpty else {
            return nil
        }

        guard originalChanged.count <= 8, correctedChanged.count <= 8 else {
            return nil
        }

        let originalPhrase = originalChanged.joined(separator: " ").trimmedForLearning
        let correctedPhrase = correctedChanged.joined(separator: " ").trimmedForLearning

        guard originalPhrase.count >= 3, correctedPhrase.count >= 2 else {
            return nil
        }

        guard !originalPhrase.isSameSpokenPhrase(as: correctedPhrase) || originalPhrase != correctedPhrase else {
            return nil
        }

        return LearnedReplacement(
            original: originalPhrase,
            replacement: correctedPhrase,
            source: .correction(id)
        )
    }
}

struct LearnedReplacement: Equatable {
    enum Source: Equatable {
        case correction(UUID)
        case vocabulary(UUID)
    }

    let original: String
    let replacement: String
    let source: Source
}

extension String {
    var transcriptWords: [String] {
        trimmedForLearning
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    var trimmedForLearning: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
    }

    func isSameSpokenPhrase(as other: String) -> Bool {
        spokenNormalized == other.spokenNormalized
    }

    var spokenNormalized: String {
        lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9]+",
                with: " ",
                options: .regularExpression
            )
            .trimmedForLearning
    }
}
