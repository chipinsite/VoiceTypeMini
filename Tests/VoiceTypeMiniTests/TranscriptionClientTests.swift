import Foundation
import XCTest
@testable import VoiceTypeMini

final class TranscriptionClientTests: XCTestCase {
    func testStubTranscriberReturnsPreviewText() async throws {
        let client = StubTranscriptionClient()
        let text = try await client.transcribe(audioFileURL: URL(fileURLWithPath: "/dev/null"))

        XCTAssertTrue(text.contains("VoiceTypeMini"))
    }
}
