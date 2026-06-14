import SwiftUI

@main
struct VoiceTypeMiniApp: App {
    @StateObject private var appState: AppState
    @StateObject private var updateController: UpdateController

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        _updateController = StateObject(wrappedValue: UpdateController())
        RecordingOverlayWindowController.shared.bind(to: state)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(appState: appState, updateController: updateController)
        } label: {
            Image(systemName: appState.menuBarIconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
