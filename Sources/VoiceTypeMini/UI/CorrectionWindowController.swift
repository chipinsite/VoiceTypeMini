import AppKit
import SwiftUI

@MainActor
final class CorrectionWindowController {
    static let shared = CorrectionWindowController()

    private var window: NSWindow?
    private var windowDelegate: CorrectionWindowDelegate?

    private init() {}

    func show(
        title: String,
        originalText: String,
        correctedText: String,
        onSave: @escaping (String) -> Void
    ) {
        window?.close()

        let hostingController = NSHostingController(
            rootView: CorrectionEditorView(
                title: title,
                originalText: originalText,
                correctedText: correctedText,
                onCancel: { [weak self] in
                    self?.window?.close()
                },
                onSave: { [weak self] correctedText in
                    onSave(correctedText)
                    self?.window?.close()
                }
            )
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 640, height: 520))
        window.minSize = NSSize(width: 520, height: 420)
        window.center()
        let delegate = CorrectionWindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        window.delegate = delegate
        windowDelegate = delegate

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class CorrectionWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
