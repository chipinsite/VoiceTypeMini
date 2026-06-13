import Foundation
import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private enum Constants {
        static let keychainService = "com.local.voicetypemini"
        static let openAIAccount = "openai-api-key"
        static let whisperModelKey = "whisperkit-model"
        static let backendKey = "transcription-backend"
        static let insertionModeKey = "insertion-mode"
        static let preserveClipboardKey = "preserve-clipboard"
        static let pushToTalkHotkeyKey = "push-to-talk-hotkey"
    }

    enum Status: Equatable {
        case idle
        case recording
        case transcribing
        case recorded(URL)
        case ready(String)
        case pasted(String)
        case copied(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published var selectedBackend: TranscriptionBackend = .whisperKit {
        didSet {
            UserDefaults.standard.set(selectedBackend.rawValue, forKey: Constants.backendKey)
        }
    }
    @Published var selectedWhisperModel: WhisperKitModel = .base {
        didSet {
            UserDefaults.standard.set(selectedWhisperModel.rawValue, forKey: Constants.whisperModelKey)
            whisperKitTranscriber.setModel(selectedWhisperModel.rawValue)
        }
    }
    @Published var openAIAPIKey: String = ""
    @Published var selectedInsertionMode: TextInsertionController.InsertionMode = .automatic {
        didSet {
            insertionController.insertionMode = selectedInsertionMode
            UserDefaults.standard.set(selectedInsertionMode.rawValue, forKey: Constants.insertionModeKey)
            refreshInsertionStatus()
        }
    }
    @Published var preserveClipboard: Bool = true {
        didSet {
            insertionController.shouldPreserveClipboard = preserveClipboard
            UserDefaults.standard.set(preserveClipboard, forKey: Constants.preserveClipboardKey)
        }
    }
    @Published var selectedPushToTalkHotkey: PushToTalkHotkeyController.Hotkey = .controlOptionSpace {
        didSet {
            UserDefaults.standard.set(selectedPushToTalkHotkey.rawValue, forKey: Constants.pushToTalkHotkeyKey)
            restartPushToTalkHotkey()
        }
    }
    @Published private(set) var hotkeyStatusText: String = "Push-to-talk not enabled"
    @Published private(set) var insertionStatusText: String = "Paste: not checked"
    @Published private(set) var permissionHealthText: String = "Permissions: not checked"
    @Published private(set) var pasteTargetStatusText: String = "Paste target: not captured yet"
    @Published private(set) var launchAtLoginStatusText: String = "Launch at login: not checked"
    @Published private(set) var transcriptHistory: [TranscriptHistoryItem] = []

    private let previewTranscriber: TranscriptionClient = StubTranscriptionClient()
    private let whisperKitTranscriber = WhisperKitTranscriptionClient(model: "base")
    private let recorder = AudioRecorder()
    private let hotkeyController = PushToTalkHotkeyController()
    private let insertionController = TextInsertionController()
    private let frontmostApplicationTracker = FrontmostApplicationTracker()
    private let launchAtLoginController = LaunchAtLoginController()
    private let historyStore = TranscriptHistoryStore()
    private var lastRecordingURL: URL?
    private var appActivationObserver: NSObjectProtocol?

    init() {
        openAIAPIKey = (try? KeychainStore.read(
            service: Constants.keychainService,
            account: Constants.openAIAccount
        )) ?? ""
        transcriptHistory = historyStore.load()
        if let savedBackend = UserDefaults.standard.string(forKey: Constants.backendKey),
           let backend = TranscriptionBackend(rawValue: savedBackend) {
            selectedBackend = backend
        }
        if let savedModel = UserDefaults.standard.string(forKey: Constants.whisperModelKey),
           let model = WhisperKitModel(rawValue: savedModel) {
            selectedWhisperModel = model
            whisperKitTranscriber.setModel(model.rawValue)
        } else {
            whisperKitTranscriber.setModel(selectedWhisperModel.rawValue)
        }
        if let savedInsertionMode = UserDefaults.standard.string(forKey: Constants.insertionModeKey),
           let insertionMode = TextInsertionController.InsertionMode(rawValue: savedInsertionMode) {
            selectedInsertionMode = insertionMode
        }
        preserveClipboard = UserDefaults.standard.object(forKey: Constants.preserveClipboardKey)
            .map { _ in UserDefaults.standard.bool(forKey: Constants.preserveClipboardKey) } ?? true
        if let savedHotkey = UserDefaults.standard.string(forKey: Constants.pushToTalkHotkeyKey),
           let hotkey = PushToTalkHotkeyController.Hotkey(rawValue: savedHotkey) {
            selectedPushToTalkHotkey = hotkey
        }
        applyInsertionPreferences()

        hotkeyController.onPress = { [weak self] in
            self?.startPushToTalkRecording()
        }
        hotkeyController.onRelease = { [weak self] in
            self?.finishPushToTalkRecording()
        }

        enablePushToTalk()
        refreshInsertionStatus()
        refreshLaunchAtLoginStatus()

        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.retryPushToTalkIfNeeded()
            }
        }
    }

    var isRecording: Bool {
        status == .recording
    }

    var shouldShowOverlay: Bool {
        switch status {
        case .recording, .transcribing, .pasted, .copied, .failed:
            return true
        default:
            return false
        }
    }

    var overlayTitle: String {
        switch status {
        case .recording:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .pasted:
            return "Pasted"
        case .copied:
            return "Copied"
        case .failed:
            return "Needs attention"
        default:
            return statusText
        }
    }

    var overlaySubtitle: String {
        switch status {
        case .recording:
            return "Release hotkey or press stop"
        case .transcribing:
            return selectedBackend == .whisperKit
                ? "WhisperKit \(selectedWhisperModel.displayName)"
                : selectedBackend.rawValue
        case .pasted:
            return insertionStatusText.replacingOccurrences(of: "Paste: ", with: "")
        case .copied:
            return insertionStatusText.replacingOccurrences(of: "Paste: ", with: "")
        case let .failed(message):
            return message
        default:
            return "VoiceTypeMini"
        }
    }

    var overlayIconName: String {
        switch status {
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .pasted:
            return "checkmark"
        case .copied:
            return "doc.on.clipboard"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return menuBarIconName
        }
    }

    var overlayTint: Color {
        switch status {
        case .recording:
            return .red
        case .transcribing:
            return .teal
        case .pasted:
            return .green
        case .copied:
            return .blue
        case .failed:
            return .orange
        default:
            return .gray
        }
    }

    var menuBarIconName: String {
        switch status {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .recorded, .ready, .pasted, .copied:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch status {
        case .idle:
            return "Ready"
        case .recording:
            return "Listening..."
        case .transcribing:
            return "Transcribing..."
        case .recorded:
            return "Recording saved"
        case .ready:
            return "Transcript ready"
        case .pasted:
            return "Transcript pasted"
        case .copied:
            return "Transcript copied"
        case .failed:
            return "Error"
        }
    }

    var statusDetailText: String? {
        switch status {
        case let .failed(message):
            return message
        case .pasted:
            return insertionStatusText.replacingOccurrences(of: "Paste: ", with: "")
        case .copied:
            return "Accessibility is not enabled. Transcript is copied to clipboard."
        case .transcribing:
            if selectedBackend == .whisperKit {
                return "Backend: WhisperKit \(selectedWhisperModel.displayName)"
            }
            return "Backend: \(selectedBackend.rawValue)"
        case .recording:
            return "Release \(selectedPushToTalkHotkey.displayName) to transcribe."
        default:
            return nil
        }
    }

    var lastTranscript: String? {
        switch status {
        case let .ready(text), let .pasted(text), let .copied(text):
            return text
        default:
            return nil
        }
    }

    var recordingPath: String? {
        guard case let .recorded(url) = status else {
            return nil
        }
        return url.path
    }

    var hasRecording: Bool {
        lastRecordingURL != nil
    }

    var hasOpenAIAPIKey: Bool {
        !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAccessibilityPermission: Bool {
        insertionController.hasPastePermission
    }

    var insertionModes: [TextInsertionController.InsertionMode] {
        TextInsertionController.InsertionMode.allCases
    }

    var pushToTalkHotkeys: [PushToTalkHotkeyController.Hotkey] {
        PushToTalkHotkeyController.Hotkey.allCases
    }

    var isHotkeyEnabled: Bool {
        hotkeyController.isEnabled
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginController.status.isEnabled
    }

    func enablePushToTalk() {
        do {
            try hotkeyController.start(hotkey: selectedPushToTalkHotkey)
            hotkeyStatusText = "Push-to-talk: \(selectedPushToTalkHotkey.displayName)"
        } catch {
            hotkeyStatusText = "\(error.localizedDescription) Try quitting conflicting apps or choose a different shortcut later."
        }
    }

    func retryPushToTalkIfNeeded() {
        refreshInsertionStatus()
        refreshLaunchAtLoginStatus()

        guard !hotkeyController.isEnabled else {
            return
        }

        enablePushToTalk()
    }

    func restartPushToTalkHotkey() {
        guard hotkeyController.isEnabled else {
            enablePushToTalk()
            return
        }

        hotkeyController.stop()
        enablePushToTalk()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginStatusText = "Launch at login: \(error.localizedDescription)"
        }
    }

    func saveOpenAIAPIKey() {
        do {
            let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedKey.isEmpty {
                try KeychainStore.delete(
                    service: Constants.keychainService,
                    account: Constants.openAIAccount
                )
                openAIAPIKey = ""
            } else {
                try KeychainStore.write(
                    trimmedKey,
                    service: Constants.keychainService,
                    account: Constants.openAIAccount
                )
                openAIAPIKey = trimmedKey
            }
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func recordFiveSecondClip() {
        Task {
            do {
                try await startRecording()
                try await Task.sleep(nanoseconds: 5_000_000_000)
                try stopRecording()
            } catch {
                if recorder.isRecording {
                    _ = try? recorder.stop()
                }
                status = .failed(error.localizedDescription)
            }
        }
    }

    func startPushToTalkRecording() {
        Task {
            do {
                try await startRecording()
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func finishPushToTalkRecording() {
        guard isRecording else {
            return
        }

        do {
            try stopRecording()
            transcribeLastRecording()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func startRecording() async throws {
        if recorder.isRecording {
            recorder.cancel()
        }

        frontmostApplicationTracker.captureCurrentFrontmostApplication()
        refreshPasteTargetStatus()

        let previousRecordingURL = lastRecordingURL
        lastRecordingURL = nil

        status = .recording
        do {
            try await recorder.start()
            recorder.discard(previousRecordingURL)
        } catch {
            lastRecordingURL = previousRecordingURL
            status = previousRecordingURL.map { .recorded($0) } ?? .idle
            throw error
        }
    }

    private func stopRecording() throws {
        let url = try recorder.stop()
        lastRecordingURL = url
        status = .recorded(url)
    }

    func runPreviewTranscription() {
        status = .recording

        Task {
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                status = .transcribing
                let transcript = try await previewTranscriber.transcribe(audioFileURL: URL(fileURLWithPath: "/dev/null"))
                status = .ready(transcript)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func transcribeLastRecording() {
        guard let lastRecordingURL else {
            status = .failed("No recording is available to transcribe.")
            return
        }

        guard FileManager.default.fileExists(atPath: lastRecordingURL.path) else {
            status = .failed("Recording file is missing: \(lastRecordingURL.path)")
            self.lastRecordingURL = nil
            return
        }

        Task {
            do {
                status = .transcribing
                let client = try transcriptionClient()
                let transcript = try await client.transcribe(audioFileURL: lastRecordingURL)
                addTranscriptToHistory(transcript)
                let targetName = await frontmostApplicationTracker.activateTargetForPaste()
                let insertionResult = await insertionController.insert(transcript)
                handleInsertionResult(insertionResult, text: transcript, targetName: targetName)
                hideOverlayAfterDelay()
            } catch {
                status = .failed(error.localizedDescription)
                hideOverlayAfterDelay(seconds: 4)
            }
        }
    }

    private func transcriptionClient() throws -> TranscriptionClient {
        switch selectedBackend {
        case .whisperKit:
            return whisperKitTranscriber
        case .openAI:
            let apiKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw AppError.missingOpenAIAPIKey
            }
            return OpenAITranscriptionClient(apiKey: apiKey)
        case .appleSpeech:
            throw AppError.appleSpeechNotImplemented
        }
    }

    func reset() {
        if recorder.isRecording {
            recorder.cancel()
        }
        recorder.discard(lastRecordingURL)
        lastRecordingURL = nil
        status = .idle
    }

    func copyTranscript(_ item: TranscriptHistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        insertionStatusText = "Copied history item"
    }

    func pasteTranscript(_ item: TranscriptHistoryItem) {
        Task {
            let targetName = await frontmostApplicationTracker.activateTargetForPaste()
            let result = await insertionController.insert(item.text)
            handleInsertionResult(result, text: item.text, targetName: targetName)
            hideOverlayAfterDelay()
        }
    }

    func pasteLastTranscript() {
        guard let lastTranscript else {
            status = .failed("No transcript is available to paste.")
            hideOverlayAfterDelay(seconds: 3)
            return
        }

        Task {
            let targetName = await frontmostApplicationTracker.activateTargetForPaste()
            let result = await insertionController.insert(lastTranscript)
            handleInsertionResult(result, text: lastTranscript, targetName: targetName)
            hideOverlayAfterDelay()
        }
    }

    func testInsertion() {
        Task {
            let testText = "VoiceTypeMini insertion test"
            let targetName = await frontmostApplicationTracker.activateTargetForPaste()
            let result = await insertionController.insert(testText)
            handleInsertionResult(result, text: testText, targetName: targetName)
            hideOverlayAfterDelay()
        }
    }

    func clearTranscriptHistory() {
        transcriptHistory = []
        historyStore.clear()
    }

    private func hideOverlayAfterDelay(seconds: UInt64 = 2) {
        Task {
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            switch status {
            case .pasted, .copied, .failed:
                if let transcript = lastTranscript {
                    status = .ready(transcript)
                } else {
                    status = .idle
                }
            default:
                break
            }
        }
    }

    func requestAccessibilityPermission() {
        insertionController.requestPastePermissionPrompt()
        refreshInsertionStatus()
    }

    func openAccessibilitySettings() {
        openPrivacySettingsPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacySettingsPane("Privacy_ListenEvent")
    }

    func refreshInsertionStatus() {
        let health = insertionController.permissionHealth
        permissionHealthText = health.canAutoInsert
            ? "Permissions: \(health.summary)"
            : "Permissions: enable Accessibility or Input Monitoring"
        insertionStatusText = health.canAutoInsert
            ? "Paste: \(selectedInsertionMode.label.lowercased())"
            : "Paste: clipboard fallback only"
        refreshPasteTargetStatus()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatusText = launchAtLoginController.status.description
    }

    private func refreshPasteTargetStatus() {
        pasteTargetStatusText = frontmostApplicationTracker.targetName.map { "Paste target: \($0)" }
            ?? "Paste target: open a text app first"
    }

    private func handleInsertionResult(
        _ result: TextInsertionController.InsertionResult,
        text: String,
        targetName: String?
    ) {
        if let targetName {
            pasteTargetStatusText = "Paste target: \(targetName)"
        } else {
            refreshPasteTargetStatus()
        }

        switch result {
        case .insertedDirectly:
            status = .pasted(text)
            insertionStatusText = targetName.map { "Paste: inserted in \($0)" } ?? "Paste: inserted directly"
        case .sentPasteShortcut:
            status = .pasted(text)
            insertionStatusText = targetName.map { "Paste: command sent to \($0)" } ?? "Paste: command sent"
        case .copied:
            status = .copied(text)
            insertionStatusText = "Paste: copied only - enable Auto-Paste"
        }
    }

    private func addTranscriptToHistory(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        let item = TranscriptHistoryItem(
            text: trimmedText,
            backend: selectedBackend.rawValue,
            model: selectedBackend == .whisperKit ? selectedWhisperModel.rawValue : nil
        )
        transcriptHistory = historyStore.add(item, to: transcriptHistory)
    }

    private func applyInsertionPreferences() {
        insertionController.insertionMode = selectedInsertionMode
        insertionController.shouldPreserveClipboard = preserveClipboard
    }

    private func openPrivacySettingsPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private enum AppError: LocalizedError {
    case missingOpenAIAPIKey
    case appleSpeechNotImplemented

    var errorDescription: String? {
        switch self {
        case .missingOpenAIAPIKey:
            return "Add your OpenAI API key in Settings first."
        case .appleSpeechNotImplemented:
            return "Apple Speech is not wired yet. Choose WhisperKit or OpenAI in Settings."
        }
    }
}
