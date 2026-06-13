import AppKit
import Foundation

@MainActor
final class FrontmostApplicationTracker {
    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private var lastApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    init() {
        captureCurrentFrontmostApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                self?.remember(app)
            }
        }
    }

    var targetName: String? {
        validLastApplication?.localizedName
    }

    func captureCurrentFrontmostApplication() {
        if let app = NSWorkspace.shared.frontmostApplication {
            remember(app)
        }
    }

    func activateTargetForPaste() async -> String? {
        guard let app = validLastApplication else {
            return nil
        }

        app.activate(options: [.activateAllWindows])
        try? await Task.sleep(nanoseconds: 650_000_000)
        return app.localizedName
    }

    private var validLastApplication: NSRunningApplication? {
        guard let lastApplication,
              !lastApplication.isTerminated,
              lastApplication.bundleIdentifier != ownBundleIdentifier else {
            return nil
        }

        return lastApplication
    }

    private func remember(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != ownBundleIdentifier,
              app.activationPolicy == .regular,
              !app.isTerminated else {
            return
        }

        lastApplication = app
    }
}
