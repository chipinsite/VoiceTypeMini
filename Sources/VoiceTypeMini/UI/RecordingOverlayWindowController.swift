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
            .sink { [weak self] isExpanded in
                self?.handleDockExpansionChange(isExpanded: isExpanded, appState: appState)
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
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.setContentSize(RecordingOverlayMetrics.idleSize)

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

    private func handleDockExpansionChange(isExpanded: Bool, appState: AppState) {
        if shouldKeepDockExpanded(isExpanded: isExpanded, appState: appState) {
            appState.isDockExpanded = true
            return
        }

        updateWindow(appState: appState)
    }

    private func shouldKeepDockExpanded(isExpanded: Bool, appState: AppState) -> Bool {
        guard !isExpanded, !appState.isRecording, !appState.shouldShowOverlay else {
            return false
        }

        return isMouseInsideOverlay(padding: 10)
    }

    func isMouseInsideOverlay(padding: CGFloat = 0) -> Bool {
        guard let window else {
            return false
        }

        let paddedFrame = window.frame.insetBy(dx: -padding, dy: -padding)
        return paddedFrame.contains(NSEvent.mouseLocation)
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
            return RecordingOverlayMetrics.recordingSize
        }

        if appState.isDockExpanded || appState.shouldShowOverlay {
            return appState.shouldShowOverlay && !appState.isRecording
                ? RecordingOverlayMetrics.statusSize
                : RecordingOverlayMetrics.expandedSize
        }

        return RecordingOverlayMetrics.idleSize
    }
}
