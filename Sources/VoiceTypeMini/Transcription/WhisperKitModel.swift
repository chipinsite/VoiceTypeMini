import Foundation

enum WhisperKitModel: String, CaseIterable, Identifiable {
    case tiny
    case base
    case small

    var id: String { rawValue }

    static var selectableCases: [WhisperKitModel] {
        [.base]
    }

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .small:
            return "Small"
        }
    }

    var description: String {
        switch self {
        case .tiny:
            return "Fastest, lowest accuracy. Good for testing."
        case .base:
            return "Balanced default for quick personal dictation."
        case .small:
            return "Better accuracy, slower and larger download."
        }
    }
}
