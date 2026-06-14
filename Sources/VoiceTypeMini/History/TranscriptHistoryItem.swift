import Foundation

struct TranscriptHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let rawText: String?
    let learnedCorrectionsApplied: [String]
    let backend: String
    let model: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        rawText: String? = nil,
        learnedCorrectionsApplied: [String] = [],
        backend: String,
        model: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.rawText = rawText
        self.learnedCorrectionsApplied = learnedCorrectionsApplied
        self.backend = backend
        self.model = model
        self.createdAt = createdAt
    }

    var preview: String {
        if text.count <= 48 {
            return text
        }

        return String(text.prefix(45)) + "..."
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case rawText
        case learnedCorrectionsApplied
        case backend
        case model
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
        learnedCorrectionsApplied = try container.decodeIfPresent(
            [String].self,
            forKey: .learnedCorrectionsApplied
        ) ?? []
        backend = try container.decode(String.self, forKey: .backend)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
