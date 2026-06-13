import Foundation
import Testing
@testable import VoiceTypeMini

@Test
func stubTranscriberReturnsPreviewText() async throws {
    let client = StubTranscriptionClient()
    let text = try await client.transcribe(audioFileURL: URL(fileURLWithPath: "/dev/null"))

    #expect(text.contains("VoiceTypeMini"))
}
