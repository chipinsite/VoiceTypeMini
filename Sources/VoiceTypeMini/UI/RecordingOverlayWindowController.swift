import AppKit
import Combine
import SwiftUI

@MainActor
final class RecordingOverlayWindowController {
    static let shared = RecordingOverlayWindowController()

    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    private init() {}

    func bind(to appState: AppState) {
        if window == nil {
            createWindow(appState: appState)
        }

        cancellable = appState.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateVisibility(appState: appState)
            }

        updateVisibility(appState: appState)
    }

    private func createWindow(appState: AppState) {
        let hostingController = NSHostingController(rootView: RecordingOverlayView(appState: appState))
        let window = NSPanel(contentViewController: hostingController)
        window.styleMask = [.borderless, .nonactivatingPanel]
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.setContentSize(NSSize(width: 310, height: 64))

        self.window = window
        position(window: window)
    }

    private func updateVisibility(appState: AppState) {
        guard let window else {
            return
        }

        if appState.shouldShowOverlay {
            position(window: window)
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    private func position(window: NSWindow) {
        guard let screen = NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - 24
        )

        window.setFrameOrigin(origin)
    }
}
