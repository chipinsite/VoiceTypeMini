import AppKit
import Combine
import SwiftUI

@MainActor
final class RecordingOverlayWindowController {
    static let shared = RecordingOverlayWindowController()

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func bind(to appState: AppState) {
        if window == nil {
            createWindow(appState: appState)
        }

        cancellables.removeAll()

        appState.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindow(appState: appState)
            }
            .store(in: &cancellables)

        appState.$isDockExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindow(appState: appState)
            }
            .store(in: &cancellables)

        updateWindow(appState: appState)
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
        window.setContentSize(Self.idleSize)

        self.window = window
        position(window: window)
    }

    private func updateWindow(appState: AppState) {
        guard let window else {
            return
        }

        resize(window: window, to: targetSize(for: appState))
        position(window: window)
        window.orderFrontRegardless()
    }

    private func resize(window: NSWindow, to size: NSSize) {
        guard window.frame.size != size else {
            return
        }

        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
    }

    private func position(window: NSWindow) {
        guard let screen = NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.minY + 4
        )

        window.setFrameOrigin(origin)
    }

    private func targetSize(for appState: AppState) -> NSSize {
        if appState.isRecording {
            return Self.recordingSize
        }

        if appState.isDockExpanded || appState.shouldShowOverlay {
            return appState.shouldShowOverlay && !appState.isRecording ? Self.statusSize : Self.expandedSize
        }

        return Self.idleSize
    }

    private static let idleSize = NSSize(width: 86, height: 18)
    private static let recordingSize = NSSize(width: 214, height: 58)
    private static let expandedSize = NSSize(width: 292, height: 82)
    private static let statusSize = NSSize(width: 292, height: 98)
}
