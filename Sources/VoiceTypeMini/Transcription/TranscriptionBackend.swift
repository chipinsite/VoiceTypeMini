import Foundation

enum TranscriptionBackend: String, CaseIterable, Identifiable {
    case whisperKit = "WhisperKit"
    case appleSpeech = "Apple Speech"
    case openAI = "OpenAI"

    var id: String { rawValue }

    static var selectableCases: [TranscriptionBackend] {
        [.whisperKit, .appleSpeech, .openAI]
    }

    var description: String {
        switch self {
        case .whisperKit:
            return "Local Whisper transcription on your Mac."
        case .appleSpeech:
            return "Apple speech recognition. Uses on-device recognition when available, with an online fallback."
        case .openAI:
            return "Cloud transcription using OpenAI speech-to-text."
        }
    }
}
