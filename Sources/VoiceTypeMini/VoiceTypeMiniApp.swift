import SwiftUI

@main
struct VoiceTypeMiniApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        RecordingOverlayWindowController.shared.bind(to: state)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(appState: appState)
        } label: {
            Image(systemName: appState.menuBarIconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
