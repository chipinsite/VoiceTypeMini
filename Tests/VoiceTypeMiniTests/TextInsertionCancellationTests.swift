import AppKit
import XCTest
@testable import VoiceTypeMini

final class TextInsertionCancellationTests: XCTestCase {
    @MainActor
    func testCancelledInsertionDoesNotChangeClipboard() async {
        let controller = TextInsertionController()
        let before = NSPasteboard.general.changeCount
        let task = Task { @MainActor in
            await controller.insert("Cancelled transcript must not paste", targetProcessIdentifier: nil)
        }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
    }
}
