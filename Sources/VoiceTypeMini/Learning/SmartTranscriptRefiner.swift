import Foundation

struct SmartTranscriptContext {
    let backend: String
    let model: String?
    let targetApplication: String?
    let targetAppCategory: String
    let focusedTextContext: FocusedTextContext?
    let vocabulary: [PersonalVocabularyEntry]
    let correctionExamples: [CorrectionExample]
}

struct SmartTranscriptRefiner {
    enum RefinerError: LocalizedError {
        case invalidResponse
        case requestFailed(Int, String)
        case missingText

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Smart dictation returned an invalid response."
            case let .requestFailed(statusCode, body):
                return "Smart dictation failed with HTTP \(statusCode): \(body)"
            case .missingText:
                return "Smart dictation did not return text."
            }
        }
    }

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    func refine(_ transcript: String, context: SmartTranscriptContext) async throws -> String {
        let trimmedTranscript = transcript.trimmedForLearning
        guard !trimmedTranscript.isEmpty else {
            return trimmedTranscript
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: model,
                temperature: 0.1,
                messages: [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userPrompt(for: trimmedTranscript, context: context))
                ]
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RefinerError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RefinerError.requestFailed(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            )
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content.trimmedForLearning,
              !text.isEmpty
        else {
            throw RefinerError.missingText
        }

        return text
    }

    private var systemPrompt: String {
        """
        You are the smart dictation cleanup layer for a macOS voice typing app.
        Rewrite raw speech-to-text into the text the speaker likely intended.
        Preserve meaning and facts. Do not invent names, numbers, dates, links, or commitments.
        Use personal vocabulary and correction examples as strong hints.
        Fix punctuation, casing, spacing, homophones, obvious ASR errors, and repeated filler.
        Keep the user's voice and tone. Output only the final text.
        """
    }

    private func userPrompt(for transcript: String, context: SmartTranscriptContext) -> String {
        var sections: [String] = [
            "Raw transcript:\n\(transcript)",
            "Speech engine: \(context.backend)\(context.model.map { " / \($0)" } ?? "")",
            "Target app: \(context.targetApplication ?? "Unknown")",
            "Target app category: \(context.targetAppCategory)"
        ]

        if let focusedTextContext = context.focusedTextContext {
            var focusLines: [String] = []
            if let roleDescription = focusedTextContext.roleDescription {
                focusLines.append("Focused field: \(roleDescription)")
            }
            if let selectedText = focusedTextContext.selectedText {
                focusLines.append("Selected text: \(selectedText)")
            }
            focusLines.append("Nearby text:\n\(focusedTextContext.nearbyText)")
            sections.append("Focused text context:\n\(focusLines.joined(separator: "\n"))")
        }

        sections.append("Formatting guidance:\n\(formattingGuidance(for: context.targetAppCategory))")

        let vocabularyLines = context.vocabulary
            .prefix(80)
            .map { entry -> String in
                if entry.spokenForms.isEmpty {
                    return "- \(entry.phrase)"
                }

                return "- \(entry.phrase) (heard as: \(entry.spokenForms.joined(separator: ", ")))"
            }

        if !vocabularyLines.isEmpty {
            sections.append("Personal vocabulary:\n\(vocabularyLines.joined(separator: "\n"))")
        }

        let correctionLines = context.correctionExamples
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { "- Heard: \($0.originalText)\n  Corrected: \($0.correctedText)" }

        if !correctionLines.isEmpty {
            sections.append("Recent correction examples:\n\(correctionLines.joined(separator: "\n"))")
        }

        sections.append("Return the cleaned transcript only.")
        return sections.joined(separator: "\n\n")
    }

    private func formattingGuidance(for appCategory: String) -> String {
        switch appCategory {
        case "messaging":
            return "Prefer natural, concise message style. Do not force a formal final period on very short replies."
        case "email":
            return "Use polished email-style punctuation and capitalization. Preserve greetings and sign-offs if spoken."
        case "docs":
            return "Use clean paragraphing. Preserve list-like structure if the user dictates items."
        case "code":
            return "Preserve technical terms, filenames, symbols, camelCase, snake_case, and commands where likely."
        case "browser", "ai-chat":
            return "Write as a clear prompt or web text entry. Preserve names, product terms, and exact questions."
        default:
            return "Use clear everyday writing with natural punctuation."
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [ChatMessage]
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
