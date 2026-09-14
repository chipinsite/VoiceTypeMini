import AppKit
import Foundation

@MainActor
final class FrontmostApplicationTracker {
    struct PasteTarget {
        let name: String
        let processIdentifier: pid_t
    }

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

    func activateTargetForPaste() async -> PasteTarget? {
        guard !Task.isCancelled, let app = validLastApplication else {
            return nil
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
            guard app.activate(options: [.activateAllWindows]) else {
                return nil
            }
        }

        for _ in 0..<20 {
            guard !Task.isCancelled else { return nil }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                // Give the target window time to restore its focused text field.
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return nil }
                return PasteTarget(
                    name: app.localizedName ?? "the previous app",
                    processIdentifier: app.processIdentifier
                )
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return nil
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
