import AppKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MenuHeader(appState: appState)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Open Control Center...") {
                    SettingsWindowController.shared.show(appState: appState)
                }

                Button("Paste Last Transcript") {
                    appState.pasteLastTranscript()
                }
                .disabled(appState.lastTranscript == nil)

                Button("Correct & Learn...") {
                    appState.openCorrectionEditorForLastTranscript()
                }
                .disabled(appState.lastTranscript == nil)
            }

            if let transcript = appState.lastTranscript {
                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("Last transcript")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(transcript)
                        .font(.caption)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }

            if !appState.transcriptHistory.isEmpty {
                Divider()

                Text("Recent transcripts")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(appState.transcriptHistory.prefix(3)) { item in
                    Menu(item.preview) {
                        Button("Paste") {
                            appState.pasteTranscript(item)
                        }

                        Button("Copy") {
                            appState.copyTranscript(item)
                        }

                        Button("Correct & Learn...") {
                            appState.openCorrectionEditor(for: item)
                        }
                    }
                }
            }

            Divider()

            Menu("Advanced") {
                Button("Enable Push-to-Talk") {
                    appState.enablePushToTalk()
                }
                .disabled(appState.isHotkeyEnabled)

                Button("Record 5 Second Clip") {
                    appState.recordFiveSecondClip()
                }
                .disabled(appState.isRecording)

                Button("Transcribe Last Recording") {
                    appState.transcribeLastRecording()
                }
                .disabled(!appState.hasRecording || appState.isRecording)

                Button("Run Preview Transcription") {
                    appState.runPreviewTranscription()
                }

                Divider()

                Button("Enable Auto-Paste") {
                    appState.requestAccessibilityPermission()
                }
                .disabled(appState.hasAccessibilityPermission)

                Button("Open Accessibility Settings") {
                    appState.openAccessibilitySettings()
                }

                Button("Open Input Monitoring Settings") {
                    appState.openInputMonitoringSettings()
                }

                Button("Test Paste Command") {
                    appState.testInsertion()
                }

                Button("Reset") {
                    appState.reset()
                }

                if !appState.transcriptHistory.isEmpty {
                    Divider()

                    Button("Clear History") {
                        appState.clearTranscriptHistory()
                    }
                }
            }

            Button("Quit VoiceTypeMini") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 280, alignment: .leading)
    }
}

private struct MenuHeader: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(appState.overlayTint)
                        .frame(width: 28, height: 28)

                    Image(systemName: appState.overlayIconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.statusText)
                        .font(.headline)

                    Text(appState.statusDetailText ?? appState.hotkeyStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                MenuStatusBadge(text: appState.selectedBackend.rawValue)
                MenuStatusBadge(text: appState.selectedPushToTalkHotkey.displayName)
            }

            Text(appState.insertionStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.pasteTargetStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MenuStatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.teal.opacity(0.14), in: Capsule())
    }
}
