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
        static let dockHotkeyMigrationKey = "dock-hotkey-migration-v1"
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
            if selectedBackend == .whisperKit {
                whisperKitTranscriber.warmUp()
            }
        }
    }
    @Published var selectedWhisperModel: WhisperKitModel = .base {
        didSet {
            UserDefaults.standard.set(selectedWhisperModel.rawValue, forKey: Constants.whisperModelKey)
            whisperKitTranscriber.setModel(selectedWhisperModel.rawValue)
            if selectedBackend == .whisperKit {
                whisperKitTranscriber.warmUp()
            }
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
    @Published var selectedPushToTalkHotkey: PushToTalkHotkeyController.Hotkey = .fnKey {
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
    @Published private(set) var correctionExamples: [CorrectionExample] = []
    @Published private(set) var personalVocabulary: [PersonalVocabularyEntry] = []
    @Published var personalVocabularyText: String = ""
    @Published private(set) var learningStatusText: String = "Learning: no corrections yet"
    @Published private(set) var whisperKitStatusText: String = "WhisperKit: preparing local model"
    @Published var isDockExpanded: Bool = false
    @Published private(set) var audioLevel: Double = 0

    private let previewTranscriber: TranscriptionClient = StubTranscriptionClient()
    private let whisperKitTranscriber = WhisperKitTranscriptionClient(model: "base")
    private let recorder = AudioRecorder()
    private let hotkeyController = PushToTalkHotkeyController()
    private let insertionController = TextInsertionController()
    private let frontmostApplicationTracker = FrontmostApplicationTracker()
    private let launchAtLoginController = LaunchAtLoginController()
    private let historyStore = TranscriptHistoryStore()
    private let correctionStore = CorrectionLearningStore()
    private let vocabularyStore = PersonalVocabularyStore()
    private var lastRecordingURL: URL?
    private var lastRawTranscript: String?
    private var appActivationObserver: NSObjectProtocol?
    private var transcriptionTask: Task<Void, Never>?
    private var transcriptionTimeoutTask: Task<Void, Never>?
    private var transcriptionGeneration = 0

    init() {
        openAIAPIKey = (try? KeychainStore.read(
            service: Constants.keychainService,
            account: Constants.openAIAccount
        )) ?? ""
        transcriptHistory = historyStore.load()
        correctionExamples = correctionStore.load()
        personalVocabulary = vocabularyStore.load()
        personalVocabularyText = PersonalVocabularyEntry.formatLines(personalVocabulary)
        refreshLearningStatus()
        whisperKitTranscriber.onPreparationStatusChange = { [weak self] status in
            self?.whisperKitStatusText = status
        }
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
        whisperKitTranscriber.warmUp()
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
        if !UserDefaults.standard.bool(forKey: Constants.dockHotkeyMigrationKey) {
            if selectedPushToTalkHotkey == .controlOptionSpace {
                selectedPushToTalkHotkey = .fnKey
            }
            UserDefaults.standard.set(true, forKey: Constants.dockHotkeyMigrationKey)
        }
        applyInsertionPreferences()

        hotkeyController.onPress = { [weak self] in
            self?.startPushToTalkRecording()
        }
        hotkeyController.onRelease = { [weak self] in
            self?.finishPushToTalkRecording()
        }
        recorder.onLevelChange = { [weak self] level in
            self?.audioLevel = level
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
                if whisperKitStatusText.hasPrefix("WhisperKit ") {
                    return whisperKitStatusText.replacingOccurrences(of: "WhisperKit ", with: "Backend: WhisperKit ")
                }

                return "Backend: \(whisperKitStatusText)"
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

    func toggleDockDictation() {
        if isRecording {
            finishPushToTalkRecording()
        } else {
            startPushToTalkRecording()
        }
    }

    func cancelDockDictation() {
        guard isRecording else {
            return
        }

        recorder.cancel()
        audioLevel = 0
        status = lastTranscript.map { .ready($0) } ?? .idle
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
        cancelActiveTranscription()

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
        audioLevel = 0
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
                lastRawTranscript = transcript
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

        cancelActiveTranscription()
        transcriptionGeneration += 1
        let generation = transcriptionGeneration
        scheduleTranscriptionTimeout(for: generation, seconds: 45)
        transcriptionTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                if self.transcriptionGeneration == generation {
                    if Task.isCancelled {
                        self.status = self.lastTranscript.map { .ready($0) } ?? .idle
                    }
                    self.transcriptionTimeoutTask?.cancel()
                    self.transcriptionTimeoutTask = nil
                    self.transcriptionTask = nil
                }
            }

            do {
                status = .transcribing
                let client = try transcriptionClient()
                let rawTranscript = try await client.transcribe(audioFileURL: lastRecordingURL)
                guard !Task.isCancelled, self.transcriptionGeneration == generation else {
                    return
                }
                let processedTranscript = postProcessTranscript(rawTranscript)
                lastRawTranscript = rawTranscript
                addTranscriptToHistory(
                    processedTranscript.text,
                    rawText: rawTranscript,
                    learnedCorrectionsApplied: processedTranscript.appliedChanges
                )
                let targetName = await frontmostApplicationTracker.activateTargetForPaste()
                let insertionResult = await insertionController.insert(processedTranscript.text)
                handleInsertionResult(insertionResult, text: processedTranscript.text, targetName: targetName)
                hideOverlayAfterDelay()
            } catch {
                guard !Task.isCancelled, self.transcriptionGeneration == generation else {
                    return
                }
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
        cancelActiveTranscription()
        if recorder.isRecording {
            recorder.cancel()
        }
        recorder.discard(lastRecordingURL)
        lastRecordingURL = nil
        lastRawTranscript = nil
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

    func openCorrectionEditorForLastTranscript() {
        guard let currentTranscript = lastTranscript else {
            status = .failed("No transcript is available to correct.")
            hideOverlayAfterDelay(seconds: 3)
            return
        }

        let originalText = lastRawTranscript ?? currentTranscript
        CorrectionWindowController.shared.show(
            title: "Correct & Learn",
            originalText: originalText,
            correctedText: currentTranscript
        ) { [weak self] correctedText in
            guard let self else {
                return
            }

            self.learnCorrection(
                originalText: originalText,
                correctedText: correctedText,
                backend: self.selectedBackend.rawValue,
                model: self.selectedBackend == .whisperKit ? self.selectedWhisperModel.rawValue : nil,
                targetApplication: self.frontmostApplicationTracker.targetName
            )
        }
    }

    func openScratchpad() {
        ScratchpadWindowController.shared.show()
    }

    func openCorrectionEditor(for item: TranscriptHistoryItem) {
        let originalText = item.rawText ?? item.text
        CorrectionWindowController.shared.show(
            title: "Correct History Item",
            originalText: originalText,
            correctedText: item.text
        ) { [weak self] correctedText in
            self?.learnCorrection(
                originalText: originalText,
                correctedText: correctedText,
                backend: item.backend,
                model: item.model,
                targetApplication: self?.frontmostApplicationTracker.targetName
            )
        }
    }

    func savePersonalVocabulary() {
        personalVocabulary = vocabularyStore.replace(with: personalVocabularyText)
        personalVocabularyText = PersonalVocabularyEntry.formatLines(personalVocabulary)
        refreshLearningStatus()
    }

    func clearLearningCorrections() {
        correctionExamples = []
        correctionStore.clear()
        refreshLearningStatus()
    }

    func clearPersonalVocabulary() {
        personalVocabulary = []
        personalVocabularyText = ""
        vocabularyStore.save([])
        refreshLearningStatus()
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

    private func learnCorrection(
        originalText: String,
        correctedText: String,
        backend: String,
        model: String?,
        targetApplication: String?
    ) {
        let original = originalText.trimmedForLearning
        let corrected = correctedText.trimmedForLearning

        guard !corrected.isEmpty else {
            status = .failed("Corrected transcript cannot be empty.")
            hideOverlayAfterDelay(seconds: 3)
            return
        }

        guard original != corrected else {
            status = .ready(corrected)
            return
        }

        let example = CorrectionExample(
            originalText: original,
            correctedText: corrected,
            backend: backend,
            model: model,
            targetApplication: targetApplication
        )
        correctionExamples = correctionStore.add(example, to: correctionExamples)
        personalVocabulary = vocabularyStore.addSuggestedPhrases(from: corrected, to: personalVocabulary)
        personalVocabularyText = PersonalVocabularyEntry.formatLines(personalVocabulary)
        lastRawTranscript = original

        addTranscriptToHistory(
            corrected,
            rawText: original,
            learnedCorrectionsApplied: ["Manual correction"],
            backend: backend,
            model: model
        )
        status = .ready(corrected)
        refreshLearningStatus()
    }

    private func cancelActiveTranscription() {
        transcriptionGeneration += 1
        transcriptionTimeoutTask?.cancel()
        transcriptionTimeoutTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    private func scheduleTranscriptionTimeout(for generation: Int, seconds: UInt64) {
        transcriptionTimeoutTask?.cancel()
        transcriptionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self,
                      self.transcriptionGeneration == generation,
                      self.status == .transcribing else {
                    return
                }

                self.transcriptionGeneration += 1
                self.transcriptionTask?.cancel()
                self.transcriptionTask = nil
                self.transcriptionTimeoutTask = nil
                self.status = .failed("Transcription took longer than \(seconds) seconds. Please try again.")
                self.hideOverlayAfterDelay(seconds: 4)
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

    private func postProcessTranscript(_ rawTranscript: String) -> ProcessedTranscript {
        let processed = TranscriptPostProcessor(
            vocabulary: personalVocabulary,
            correctionExamples: correctionExamples
        ).process(rawTranscript)

        if processed.appliedChanges.isEmpty {
            refreshLearningStatus()
        } else {
            learningStatusText = "Learning: applied \(processed.appliedChanges.count) fix(es)"
        }

        return processed
    }

    private func refreshLearningStatus() {
        learningStatusText = "Learning: \(correctionExamples.count) corrections, \(personalVocabulary.count) vocabulary terms"
    }

    private func addTranscriptToHistory(
        _ text: String,
        rawText: String? = nil,
        learnedCorrectionsApplied: [String] = [],
        backend: String? = nil,
        model: String? = nil
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        let trimmedRawText = rawText?.trimmedForLearning
        let item = TranscriptHistoryItem(
            text: trimmedText,
            rawText: trimmedRawText == trimmedText ? nil : trimmedRawText,
            learnedCorrectionsApplied: learnedCorrectionsApplied,
            backend: backend ?? selectedBackend.rawValue,
            model: model ?? (selectedBackend == .whisperKit ? selectedWhisperModel.rawValue : nil)
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
