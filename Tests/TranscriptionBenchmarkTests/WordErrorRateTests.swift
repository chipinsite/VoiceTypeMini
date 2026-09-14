import XCTest
@testable import TranscriptionBenchmark

final class WordErrorRateTests: XCTestCase {
    func testNonLatinDifferencesAreCounted() {
        for (reference, hypothesis) in [("مرحبا بالعالم", "صباح الخير"), ("你好世界", "明天见"), ("こんにちは世界", "おやすみなさい")] {
            XCTAssertGreaterThan(WordErrorRate.score(reference: reference, hypothesis: hypothesis), 0)
            XCTAssertEqual(WordErrorRate.score(reference: reference, hypothesis: reference), 0)
        }
    }

    func testAccentsAreNotDiscarded() {
        XCTAssertGreaterThan(WordErrorRate.score(reference: "café", hypothesis: "cafè"), 0)
        XCTAssertEqual(WordErrorRate.score(reference: "CAFÉ!", hypothesis: "café"), 0)
    }

    func testEmptyHypothesisCountsAllMissingWordsWithoutCrashing() {
        XCTAssertEqual(WordErrorRate.score(reference: "hello world", hypothesis: ""), 1)
        XCTAssertEqual(WordErrorRate.score(reference: "hello world", hypothesis: "..."), 1)
    }

    func testKnownEnglishSubstitution() {
        XCTAssertEqual(WordErrorRate.score(reference: "send the notes tomorrow", hypothesis: "send the notes today"), 0.25)
    }
}
