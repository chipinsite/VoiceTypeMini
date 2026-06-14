import XCTest
@testable import VoiceTypeMini

final class TranscriptPostProcessorTests: XCTestCase {
    func testVocabularyReplacesGeneratedSpokenForm() {
        let processor = TranscriptPostProcessor(
            vocabulary: [
                PersonalVocabularyEntry(phrase: "AgentFlow")
            ],
            correctionExamples: []
        )

        let processed = processor.process("open agent flow and start the run")

        XCTAssertEqual(processed.text, "open AgentFlow and start the run")
        XCTAssertEqual(processed.appliedChanges, ["agent flow -> AgentFlow"])
    }

    func testCorrectionExampleLearnsChangedPhraseInsideNewSentence() {
        let example = CorrectionExample(
            originalText: "send it to nine one tomorrow",
            correctedText: "send it to NineOne tomorrow",
            backend: "WhisperKit",
            model: "base",
            targetApplication: "Notes"
        )
        let processor = TranscriptPostProcessor(
            vocabulary: [],
            correctionExamples: [example]
        )

        let processed = processor.process("please send the proposal to nine one today")

        XCTAssertEqual(processed.text, "please send the proposal to NineOne today")
        XCTAssertEqual(processed.appliedChanges, ["nine one -> NineOne"])
    }

    func testExactCorrectionHandlesWholeTranscriptRepeats() {
        let example = CorrectionExample(
            originalText: "follow up with hay leon",
            correctedText: "follow up with Haleon",
            backend: "OpenAI",
            model: "gpt-4o-mini-transcribe",
            targetApplication: nil
        )
        let processor = TranscriptPostProcessor(
            vocabulary: [],
            correctionExamples: [example]
        )

        let processed = processor.process("follow up with hay leon")

        XCTAssertEqual(processed.text, "follow up with Haleon")
        XCTAssertTrue(processed.appliedChanges.contains("Exact correction"))
    }

    func testVocabularyLinesSupportManualSpokenAliases() {
        let entries = PersonalVocabularyEntry.parseLines("NineOne | nine one, 9 one\nAgentFlow")
        let processor = TranscriptPostProcessor(
            vocabulary: entries,
            correctionExamples: []
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(processor.process("send this to 9 one").text, "send this to NineOne")
        XCTAssertEqual(processor.process("open agent flow").text, "open AgentFlow")
    }
}
