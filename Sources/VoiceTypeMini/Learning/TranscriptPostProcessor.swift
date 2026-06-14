import Foundation

struct ProcessedTranscript: Equatable {
    let text: String
    let appliedChanges: [String]
}

struct TranscriptPostProcessor {
    let vocabulary: [PersonalVocabularyEntry]
    let correctionExamples: [CorrectionExample]

    func process(_ transcript: String) -> ProcessedTranscript {
        var text = transcript.trimmedForLearning
        var appliedChanges: [String] = []

        if let exactCorrection = exactCorrection(for: text) {
            text = exactCorrection.correctedText.trimmedForLearning
            appliedChanges.append("Exact correction")
        }

        for replacement in learnedReplacements() {
            let result = replacingPhrase(
                replacement.original,
                with: replacement.replacement,
                in: text
            )

            if result.didReplace {
                text = result.text
                appliedChanges.append("\(replacement.original) -> \(replacement.replacement)")
            }
        }

        return ProcessedTranscript(text: text, appliedChanges: appliedChanges)
    }

    private func exactCorrection(for text: String) -> CorrectionExample? {
        correctionExamples.first {
            $0.originalText.isSameSpokenPhrase(as: text)
                && !$0.correctedText.trimmedForLearning.isEmpty
        }
    }

    private func learnedReplacements() -> [LearnedReplacement] {
        var seen = Set<String>()
        var replacements: [LearnedReplacement] = []

        for entry in vocabulary {
            for spokenForm in entry.allSpokenForms {
                let original = spokenForm.trimmedForLearning
                guard original.count >= 2,
                      !original.isEmpty,
                      original != entry.phrase,
                      !original.isSameSpokenPhrase(as: entry.phrase) || original != entry.phrase
                else {
                    continue
                }

                let key = original.spokenNormalized
                guard !seen.contains(key) else {
                    continue
                }

                seen.insert(key)
                replacements.append(
                    LearnedReplacement(
                        original: original,
                        replacement: entry.phrase,
                        source: .vocabulary(entry.id)
                    )
                )
            }
        }

        for example in correctionExamples {
            guard let replacement = example.replacementCandidate else {
                continue
            }

            let key = replacement.original.spokenNormalized
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            replacements.append(replacement)
        }

        return replacements.sorted {
            if $0.original.count == $1.original.count {
                return $0.replacement.count > $1.replacement.count
            }

            return $0.original.count > $1.original.count
        }
    }

    private func replacingPhrase(
        _ phrase: String,
        with replacement: String,
        in text: String
    ) -> (text: String, didReplace: Bool) {
        let escapedPhrase = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "(?i)(?<![A-Za-z0-9])\(escapedPhrase)(?![A-Za-z0-9])"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, false)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else {
            return (text, false)
        }

        var didReplace = false
        let mutableText = NSMutableString(string: text)
        for match in matches.reversed() {
            let matchedText = mutableText.substring(with: match.range)
            guard matchedText != replacement else {
                continue
            }

            mutableText.replaceCharacters(in: match.range, with: replacement)
            didReplace = true
        }

        return (String(mutableText), didReplace)
    }
}
