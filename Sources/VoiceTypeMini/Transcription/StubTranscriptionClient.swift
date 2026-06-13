import Foundation

struct StubTranscriptionClient: TranscriptionClient {
    func transcribe(audioFileURL: URL) async throws -> String {
        "This is a test transcript from VoiceTypeMini."
    }
}
