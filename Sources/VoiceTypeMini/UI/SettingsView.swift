import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "General") {
                    SettingsRow(label: "Startup") {
                        Toggle(
                            "Launch at login",
                            isOn: Binding(
                                get: { appState.isLaunchAtLoginEnabled },
                                set: { appState.setLaunchAtLoginEnabled($0) }
                            )
                        )

                        HelpText(appState.launchAtLoginStatusText)
                    }
                }

                SettingsSection(title: "Dictation") {
                    SettingsRow(label: "Push-to-talk") {
                        Picker("", selection: $appState.selectedPushToTalkHotkey) {
                            ForEach(appState.pushToTalkHotkeys) { hotkey in
                                Text(hotkey.displayName).tag(hotkey)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 360)

                        HelpText(appState.hotkeyStatusText)
                    }
                }

                SettingsSection(title: "Insertion") {
                    SettingsRow(label: "Mode") {
                        Picker("", selection: $appState.selectedInsertionMode) {
                            ForEach(appState.insertionModes) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 360)

                        HelpText(appState.selectedInsertionMode.description)
                    }

                    SettingsRow(label: "Clipboard") {
                        Toggle("Preserve clipboard after inserting", isOn: $appState.preserveClipboard)

                        HelpText(appState.permissionHealthText)
                    }

                    SettingsRow(label: "Permissions") {
                        HStack(spacing: 10) {
                            Button("Accessibility") {
                                appState.openAccessibilitySettings()
                            }

                            Button("Input Monitoring") {
                                appState.openInputMonitoringSettings()
                            }
                        }

                        HelpText("Open macOS privacy settings if dictation records but does not insert text.")
                    }
                }

                SettingsSection(title: "Transcription") {
                    SettingsRow(label: "Provider") {
                        Picker("", selection: $appState.selectedBackend) {
                            ForEach(TranscriptionBackend.allCases) { backend in
                                Text(backend.rawValue).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 360)

                        HelpText(appState.selectedBackend.description)
                    }

                    if appState.selectedBackend == .whisperKit {
                        SettingsRow(label: "Whisper model") {
                            Picker("", selection: $appState.selectedWhisperModel) {
                                ForEach(WhisperKitModel.allCases) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 240)

                            HelpText(appState.selectedWhisperModel.description)
                        }
                    }

                    SettingsRow(label: "OpenAI API key") {
                        SecureField("API key", text: $appState.openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)

                        Button("Save OpenAI API Key") {
                            appState.saveOpenAIAPIKey()
                        }
                        .disabled(!appState.hasOpenAIAPIKey)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 680, height: 620)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .trailing)

            VStack(alignment: .leading, spacing: 7) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HelpText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 420, alignment: .leading)
    }
}
