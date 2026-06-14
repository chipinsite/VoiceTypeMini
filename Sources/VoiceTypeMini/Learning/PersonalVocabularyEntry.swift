import Foundation

struct PersonalVocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var phrase: String
    var spokenForms: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        phrase: String,
        spokenForms: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.phrase = phrase.trimmedForLearning
        self.spokenForms = spokenForms
            .map(\.trimmedForLearning)
            .filter { !$0.isEmpty }
        self.createdAt = createdAt
    }

    var allSpokenForms: [String] {
        let generated = generatedSpokenForms(for: phrase)
        return Array(Set(spokenForms + generated))
            .filter { !$0.isSameSpokenPhrase(as: phrase) || $0 != phrase }
            .sorted { $0.count > $1.count }
    }

    static func parseLines(_ text: String) -> [PersonalVocabularyEntry] {
        text
            .components(separatedBy: .newlines)
            .map { line in
                let parts = line
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { String($0).trimmedForLearning }
                let phrase = parts.first ?? ""
                let spokenForms = parts.dropFirst()
                    .flatMap { $0.components(separatedBy: ",") }
                    .map(\.trimmedForLearning)
                    .filter { !$0.isEmpty }
                return PersonalVocabularyEntry(phrase: phrase, spokenForms: spokenForms)
            }
            .filter { !$0.phrase.isEmpty }
            .deduplicatedBySpokenPhrase()
    }

    static func formatLines(_ entries: [PersonalVocabularyEntry]) -> String {
        entries
            .sorted { $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending }
            .map { entry in
                if entry.spokenForms.isEmpty {
                    return entry.phrase
                }

                return "\(entry.phrase) | \(entry.spokenForms.joined(separator: ", "))"
            }
            .joined(separator: "\n")
    }

    static func suggestedPhrases(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map { $0.trimmedForLearning }
            .filter { token in
                guard token.count >= 2 else {
                    return false
                }

                return token.hasInternalUppercase
                    || token.isUsefulAcronym
                    || token.contains(where: \.isNumber)
                    || token.contains("-")
                    || token.contains("&")
            }
            .deduplicatedBySpokenPhrase()
    }
}

private func generatedSpokenForms(for phrase: String) -> [String] {
    var forms = Set<String>()
    let camelSplit = phrase
        .replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: "([A-Z]+)([A-Z][a-z])",
            with: "$1 $2",
            options: .regularExpression
        )

    forms.insert(camelSplit.spokenNormalized)
    forms.insert(phrase.spokenNormalized)

    let acronymSpoken = phrase
        .map { character -> String in
            if character.isUppercase || character.isNumber {
                return " \(character) "
            }
            return String(character)
        }
        .joined()
        .spokenNormalized

    if acronymSpoken.count >= 3 {
        forms.insert(acronymSpoken)
    }

    return Array(forms)
        .map(\.trimmedForLearning)
        .filter { !$0.isEmpty }
}

private extension String {
    var hasInternalUppercase: Bool {
        guard count > 1 else {
            return false
        }

        return dropFirst().contains { $0.isUppercase }
    }

    var isUsefulAcronym: Bool {
        count > 1 && count <= 12 && allSatisfy { $0.isUppercase || $0.isNumber }
    }
}

private extension Array where Element == String {
    func deduplicatedBySpokenPhrase() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for item in self {
            let key = item.spokenNormalized
            guard !key.isEmpty, !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(item)
        }

        return result
    }
}

private extension Array where Element == PersonalVocabularyEntry {
    func deduplicatedBySpokenPhrase() -> [PersonalVocabularyEntry] {
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
