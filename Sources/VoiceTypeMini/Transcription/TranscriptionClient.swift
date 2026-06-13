import Foundation

@MainActor
protocol TranscriptionClient {
    func transcribe(audioFileURL: URL) async throws -> String
}
