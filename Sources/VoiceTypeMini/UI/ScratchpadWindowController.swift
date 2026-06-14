import AppKit
import SwiftUI

@MainActor
final class ScratchpadWindowController {
    static let shared = ScratchpadWindowController()

    private var window: NSWindow?
    private var windowDelegate: ScratchpadWindowDelegate?

    private init() {}

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: ScratchpadView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "VoiceTypeMini Scratchpad"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 420))
        window.minSize = NSSize(width: 420, height: 320)
        window.center()
        window.setFrameAutosaveName("VoiceTypeMiniScratchpad")
        let delegate = ScratchpadWindowDelegate { [weak self] in
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

private final class ScratchpadWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private struct ScratchpadView: View {
    @AppStorage("scratchpad-text") private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scratchpad")
                        .font(.system(size: 24, weight: .bold))

                    Text("A local place for dictated fragments before they go anywhere else.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear") {
                    text = ""
                }
                .disabled(text.isEmpty)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .padding(22)
        .frame(minWidth: 420, minHeight: 320)
    }
}
