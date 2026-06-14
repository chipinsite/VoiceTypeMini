import Combine
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdateController: ObservableObject {
    private static let publicKeyPlaceholder = "$(SPARKLE_PUBLIC_ED_KEY)"

    private(set) var configurationMessage: String = "Updates are not configured for this build."

    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif

    var canCheckForUpdates: Bool {
        #if canImport(Sparkle)
        updaterController != nil
        #else
        false
        #endif
    }

    init(bundle: Bundle = .main) {
        guard let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              URL(string: feedURL) != nil,
              let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Self.isUsablePublicKey(publicKey) else {
            return
        }

        configurationMessage = "Updates are ready."

        #if canImport(Sparkle)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #endif
    }

    private static func isUsablePublicKey(_ publicKey: String) -> Bool {
        let trimmed = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != publicKeyPlaceholder
    }
}
