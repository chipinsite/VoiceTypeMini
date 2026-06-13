import Foundation
@preconcurrency import WhisperKit

@MainActor
final class WhisperKitTranscriptionClient: TranscriptionClient {
    enum ClientError: LocalizedError {
        case missingTranscript

        var errorDescription: String? {
            switch self {
            case .missingTranscript:
                return "WhisperKit did not return transcript text."
            }
        }
    }

    private var model: String
    private var pipeline: WhisperKit?

    init(model: String = "tiny") {
        self.model = model
    }

    func setModel(_ model: String) {
        guard self.model != model else {
            return
        }

        self.model = model
        pipeline = nil
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let pipe = try await pipeline()
        let results = try await pipe.transcribe(audioPath: audioFileURL.path)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw ClientError.missingTranscript
        }

        return text
    }

    private func pipeline() async throws -> WhisperKit {
        if let pipeline {
            return pipeline
        }

        let newPipeline = try await WhisperKit(WhisperKitConfig(model: model))
        pipeline = newPipeline
        return newPipeline
    }
}
