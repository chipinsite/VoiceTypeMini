import AppKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.statusText)
                .font(.headline)

            Text(appState.hotkeyStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.insertionStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.permissionHealthText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.pasteTargetStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.launchAtLoginStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail = appState.statusDetailText {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            if let transcript = appState.lastTranscript {
                Text(transcript)
                    .font(.caption)
                    .lineLimit(3)
            }

            if let recordingPath = appState.recordingPath {
                Text(recordingPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

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

            Button("Settings...") {
                SettingsWindowController.shared.show(appState: appState)
            }

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

            Button("Paste Last Transcript") {
                appState.pasteLastTranscript()
            }
            .disabled(appState.lastTranscript == nil)

            Button("Test Paste Command") {
                appState.testInsertion()
            }

            Button("Reset") {
                appState.reset()
            }

            if !appState.transcriptHistory.isEmpty {
                Divider()

                Text("Recent Transcripts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(appState.transcriptHistory.prefix(3)) { item in
                    Menu(item.preview) {
                        Button("Paste") {
                            appState.pasteTranscript(item)
                        }

                        Button("Copy") {
                            appState.copyTranscript(item)
                        }
                    }
                }

                Button("Clear History") {
                    appState.clearTranscriptHistory()
                }
            }

            Divider()

            Button("Quit VoiceTypeMini") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 240, alignment: .leading)
    }
}
