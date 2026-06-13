import Foundation

enum TranscriptionBackend: String, CaseIterable, Identifiable {
    case whisperKit = "WhisperKit"
    case appleSpeech = "Apple Speech"
    case openAI = "OpenAI"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .whisperKit:
            return "Local Whisper transcription on your Mac."
        case .appleSpeech:
            return "Local Apple transcription for macOS 26+."
        case .openAI:
            return "Cloud transcription using OpenAI speech-to-text."
        }
    }
}
