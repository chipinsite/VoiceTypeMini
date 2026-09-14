import Foundation

struct OpenAITranscriptionClient: TranscriptionClient {
    enum ClientError: LocalizedError {
        case invalidResponse
        case requestFailed(Int, String)
        case missingTranscript

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "OpenAI returned an invalid response."
            case let .requestFailed(statusCode, body):
                return "OpenAI transcription failed with HTTP \(statusCode): \(body)"
            case .missingTranscript:
                return "OpenAI did not return transcript text."
            }
        }
    }

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o-transcribe") {
        self.apiKey = apiKey
        self.model = model
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(fileURL: audioFileURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
        guard !decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.missingTranscript
        }

        return decoded.text
    }

    private func multipartBody(fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"model\"\(lineBreak)\(lineBreak)")
        body.appendString("\(model)\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)")
        body.appendString("Content-Type: \(contentType(for: fileURL))\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.appendString(lineBreak)

        body.appendString("--\(boundary)--\(lineBreak)")

        return body
    }

    private func contentType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "caf":
            return "audio/x-caf"
        default:
            return "application/octet-stream"
        }
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    let text: String
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
