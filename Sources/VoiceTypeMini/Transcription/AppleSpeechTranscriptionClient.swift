import Foundation
import Speech

struct AppleSpeechTranscriptionClient: TranscriptionClient {
    enum ClientError: LocalizedError {
        case recognizerUnavailable
        case authorizationDenied
        case missingTranscript

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Apple Speech recognition is not available for the current locale."
            case .authorizationDenied:
                return "Speech recognition permission is not granted."
            case .missingTranscript:
                return "Apple Speech did not return transcript text."
            }
        }
    }

    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        try await requestAuthorizationIfNeeded()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw ClientError.recognizerUnavailable
        }

        // Positive path: keep Apple Speech local when possible, then fall back to Apple's standard recognizer.
        let transcript: String
        if recognizer.supportsOnDeviceRecognition {
            do {
                transcript = try await recognize(audioFileURL: audioFileURL, with: recognizer, requiresOnDeviceRecognition: true)
            } catch {
                transcript = try await recognize(audioFileURL: audioFileURL, with: recognizer, requiresOnDeviceRecognition: false)
            }
        } else {
            transcript = try await recognize(audioFileURL: audioFileURL, with: recognizer, requiresOnDeviceRecognition: false)
        }

        let trimmedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTranscript.isEmpty else {
            throw ClientError.missingTranscript
        }

        return trimmedTranscript
    }

    private func requestAuthorizationIfNeeded() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            guard status == .authorized else {
                throw ClientError.authorizationDenied
            }
        case .denied, .restricted:
            throw ClientError.authorizationDenied
        @unknown default:
            throw ClientError.authorizationDenied
        }
    }

    private func recognize(
        audioFileURL: URL,
        with recognizer: SFSpeechRecognizer,
        requiresOnDeviceRecognition: Bool
    ) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            var didResume = false
            var task: SFSpeechRecognitionTask?

            func finish(_ result: Result<String, Error>) {
                guard !didResume else {
                    return
                }

                didResume = true
                task?.cancel()
                continuation.resume(with: result)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    finish(.failure(error))
                    return
                }

                guard let result else {
                    return
                }

                if result.isFinal {
                    finish(.success(result.bestTranscription.formattedString))
                }
            }
        }
    }
}
