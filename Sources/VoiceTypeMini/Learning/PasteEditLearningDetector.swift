import Foundation

struct PasteEditLearningDetector {
    static func correctedText(
        originalFieldText: String,
        currentFieldText: String,
        insertedText: String
    ) -> String? {
        let inserted = insertedText.trimmedForLearning
        guard inserted.count >= 2,
              let insertedRange = originalFieldText.range(of: inserted) else {
            return nil
        }

        // Repeated occurrences do not identify which copy was inserted.
        guard originalFieldText.range(of: inserted, range: insertedRange.upperBound..<originalFieldText.endIndex) == nil else {
            return nil
        }
        let prefix = String(originalFieldText[..<insertedRange.lowerBound])
        let suffix = String(originalFieldText[insertedRange.upperBound...])
        guard currentFieldText.hasPrefix(prefix),
              currentFieldText.hasSuffix(suffix),
              currentFieldText.count >= prefix.count + suffix.count else {
            return nil
        }

        let replacementStart = currentFieldText.index(
            currentFieldText.startIndex,
            offsetBy: prefix.count
        )
        let replacementEnd = currentFieldText.index(
            currentFieldText.endIndex,
            offsetBy: -suffix.count
        )
        let corrected = String(currentFieldText[replacementStart..<replacementEnd]).trimmedForLearning

        guard corrected.count >= 2,
              corrected != inserted,
              // Continued typing at either edge is not evidence of a correction.
              !corrected.hasPrefix(inserted),
              !corrected.hasSuffix(inserted),
              corrected.count <= max(240, inserted.count * 4) else {
            return nil
        }

        return corrected
    }
}
