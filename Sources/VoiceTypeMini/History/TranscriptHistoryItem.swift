import Foundation

struct TranscriptHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let backend: String
    let model: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        backend: String,
        model: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
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
}
