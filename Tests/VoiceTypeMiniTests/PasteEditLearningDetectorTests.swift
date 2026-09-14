import XCTest
@testable import VoiceTypeMini

final class PasteEditLearningDetectorTests: XCTestCase {
    func testLearnsReplacementInsideUnchangedSurroundingText() {
        XCTAssertEqual(PasteEditLearningDetector.correctedText(
            originalFieldText: "Draft: send it to nine one. Thanks!",
            currentFieldText: "Draft: send it to NineOne. Thanks!",
            insertedText: "send it to nine one."
        ), "send it to NineOne.")
    }

    func testDoesNotLearnUnrelatedDocumentEdits() {
        XCTAssertNil(PasteEditLearningDetector.correctedText(
            originalFieldText: "Draft: meeting tomorrow. Thanks!",
            currentFieldText: "Final: meeting tomorrow. Thanks!",
            insertedText: "meeting tomorrow."
        ))
    }

    func testDoesNotGuessWhichRepeatedPhraseWasInserted() {
        XCTAssertNil(PasteEditLearningDetector.correctedText(
            originalFieldText: "nine one, then nine one",
            currentFieldText: "NineOne, then nine one",
            insertedText: "nine one"
        ))
    }

    func testPreservesUnicodeBoundariesAndWhitespace() {
        XCTAssertEqual(PasteEditLearningDetector.correctedText(
            originalFieldText: "  📝 café de paris\n",
            currentFieldText: "  📝 Café de Paris\n",
            insertedText: "café de paris"
        ), "Café de Paris")
    }

    func testDoesNotLearnContinuedTypingAtEitherEdge() {
        for current in ["hello world", "well hello", "hello there, world"] {
            XCTAssertNil(PasteEditLearningDetector.correctedText(
                originalFieldText: "hello", currentFieldText: current, insertedText: "hello"
            ))
        }
    }

    func testUnchangedOrDeletedTranscriptIsNotACorrection() {
        for current in ["hello world", ""] {
            XCTAssertNil(PasteEditLearningDetector.correctedText(
                originalFieldText: "hello world", currentFieldText: current, insertedText: "hello world"
            ))
        }
    }
}
