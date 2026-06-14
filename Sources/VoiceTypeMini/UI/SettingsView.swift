import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedSection: ControlCenterSection = .home

    var body: some View {
        HStack(spacing: 0) {
            ControlCenterSidebar(
                selectedSection: $selectedSection,
                transcriptCount: appState.transcriptHistory.count,
                vocabularyCount: appState.personalVocabulary.count,
                correctionCount: appState.correctionExamples.count
            )

            Divider()
                .opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VoiceTypeTheme.contentBackground)
        }
        .background(VoiceTypeTheme.shellBackground)
        .frame(width: 980, height: 690)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .home:
            HomeControlCenterView(appState: appState, selectedSection: $selectedSection)
        case .history:
            HistoryControlCenterView(appState: appState)
        case .vocabulary:
            VocabularyControlCenterView(appState: appState)
        case .corrections:
            CorrectionsControlCenterView(appState: appState)
        case .transcription:
            TranscriptionControlCenterView(appState: appState)
        case .shortcuts:
            ShortcutsControlCenterView(appState: appState)
        case .permissions:
            PermissionsControlCenterView(appState: appState)
        }
    }
}

private enum ControlCenterSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case vocabulary = "Vocabulary"
    case corrections = "Corrections"
    case transcription = "Transcription"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home:
            return "square.grid.2x2"
        case .history:
            return "text.bubble"
        case .vocabulary:
            return "book"
        case .corrections:
            return "wand.and.stars"
        case .transcription:
            return "waveform"
        case .shortcuts:
            return "keyboard"
        case .permissions:
            return "lock.shield"
        }
    }
}

private enum VoiceTypeTheme {
    static let shellBackground = Color(nsColor: NSColor(red: 0.965, green: 0.956, blue: 0.932, alpha: 1))
    static let contentBackground = Color(nsColor: NSColor(red: 0.992, green: 0.989, blue: 0.978, alpha: 1))
    static let panelBackground = Color(nsColor: NSColor(red: 0.982, green: 0.978, blue: 0.958, alpha: 1))
    static let ink = Color(nsColor: NSColor(red: 0.095, green: 0.095, blue: 0.105, alpha: 1))
    static let muted = Color(nsColor: NSColor(red: 0.46, green: 0.45, blue: 0.42, alpha: 1))
    static let border = Color.black.opacity(0.08)
    static let teal = Color(nsColor: NSColor(red: 0.05, green: 0.42, blue: 0.40, alpha: 1))
    static let tealSoft = Color(nsColor: NSColor(red: 0.82, green: 0.94, blue: 0.91, alpha: 1))
    static let purpleSoft = Color(nsColor: NSColor(red: 0.965, green: 0.92, blue: 1.0, alpha: 1))
    static let warningSoft = Color(nsColor: NSColor(red: 1.0, green: 0.92, blue: 0.76, alpha: 1))
}

private struct ControlCenterSidebar: View {
    @Binding var selectedSection: ControlCenterSection
    let transcriptCount: Int
    let vocabularyCount: Int
    let correctionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VoiceTypeTheme.teal)
                        .frame(width: 34, height: 34)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("VoiceTypeMini")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VoiceTypeTheme.ink)

                    Text("Local dictation")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VoiceTypeTheme.muted)
                }
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ControlCenterSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 21)

                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()

                            if let count = badgeCount(for: section), count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(VoiceTypeTheme.teal)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(VoiceTypeTheme.tealSoft, in: Capsule())
                            }
                        }
                        .foregroundStyle(selectedSection == section ? VoiceTypeTheme.ink : VoiceTypeTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedSection == section ? Color.black.opacity(0.055) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Private by default")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text("WhisperKit runs on this Mac. OpenAI stays available as an explicit cloud fallback.")
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(VoiceTypeTheme.purpleSoft, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(22)
        .frame(width: 246)
        .background(VoiceTypeTheme.shellBackground)
    }

    private func badgeCount(for section: ControlCenterSection) -> Int? {
        switch section {
        case .history:
            return transcriptCount
        case .vocabulary:
            return vocabularyCount
        case .corrections:
            return correctionCount
        default:
            return nil
        }
    }
}

private struct HomeControlCenterView: View {
    @ObservedObject var appState: AppState
    @Binding var selectedSection: ControlCenterSection

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HeaderBlock(
                title: "Ready to dictate",
                subtitle: "Hold \(appState.selectedPushToTalkHotkey.displayName), speak, and VoiceTypeMini inserts the transcript into the app you were using."
            ) {
                Button("Try preview") {
                    appState.runPreviewTranscription()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            HeroPanel(
                title: appState.statusText,
                subtitle: heroSubtitle,
                iconName: appState.overlayIconName
            ) {
                HStack(spacing: 10) {
                    StatusChip(text: appState.selectedBackend.rawValue, tone: .teal)
                    StatusChip(text: appState.selectedPushToTalkHotkey.displayName, tone: .light)
                    StatusChip(text: appState.isLaunchAtLoginEnabled ? "Launches at login" : "Manual launch", tone: .light)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18)
            ], spacing: 18) {
                MetricCard(
                    value: "\(appState.transcriptHistory.count)",
                    label: "recent transcripts",
                    detail: "Stored locally",
                    iconName: "text.bubble"
                )

                MetricCard(
                    value: "\(appState.personalVocabulary.count)",
                    label: "vocabulary terms",
                    detail: appState.learningStatusText.replacingOccurrences(of: "Learning: ", with: ""),
                    iconName: "book"
                )

                MetricCard(
                    value: "\(appState.correctionExamples.count)",
                    label: "learned corrections",
                    detail: "Manual fixes improve cleanup",
                    iconName: "wand.and.stars"
                )
            }

            HStack(alignment: .top, spacing: 18) {
                PanelCard(title: "Last transcript", iconName: "doc.text") {
                    if let transcript = appState.lastTranscript {
                        Text(transcript)
                            .font(.body)
                            .foregroundStyle(VoiceTypeTheme.ink)
                            .lineLimit(8)
                            .textSelection(.enabled)

                        HStack {
                            Button("Paste again") {
                                appState.pasteLastTranscript()
                            }

                            Button("Correct & Learn") {
                                appState.openCorrectionEditorForLastTranscript()
                            }
                        }
                    } else {
                        EmptyStateText("Dictate once and your latest transcript will appear here.")
                    }
                }

                PanelCard(title: "Setup health", iconName: "checkmark.shield") {
                    HealthRow(title: "Push-to-talk", value: appState.hotkeyStatusText, isHealthy: appState.isHotkeyEnabled)
                    HealthRow(title: "Insertion", value: appState.insertionStatusText, isHealthy: appState.hasAccessibilityPermission)
                    HealthRow(title: "Permissions", value: appState.permissionHealthText, isHealthy: appState.hasAccessibilityPermission)

                    Button("Open permissions") {
                        selectedSection = .permissions
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 4)
                }
            }
        }
    }

    private var heroSubtitle: String {
        appState.statusDetailText ?? appState.pasteTargetStatusText
    }
}

private struct HistoryControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "History",
                subtitle: "Recent transcripts stay on this Mac so you can paste, copy, or teach VoiceTypeMini from them."
            ) {
                Button("Clear history") {
                    appState.clearTranscriptHistory()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(appState.transcriptHistory.isEmpty)
            }

            PanelCard(title: "Recents", iconName: "clock") {
                if appState.transcriptHistory.isEmpty {
                    EmptyStateText("No transcripts yet.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.transcriptHistory) { item in
                            TranscriptHistoryRow(appState: appState, item: item)

                            if item.id != appState.transcriptHistory.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TranscriptHistoryRow: View {
    @ObservedObject var appState: AppState
    let item: TranscriptHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.createdAt, style: .time)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VoiceTypeTheme.muted)

                Text(item.text)
                    .font(.body)
                    .foregroundStyle(VoiceTypeTheme.ink)
                    .lineLimit(3)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    StatusChip(text: item.backend, tone: .teal)
                    if let model = item.model {
                        StatusChip(text: model.capitalized, tone: .light)
                    }
                    if !item.learnedCorrectionsApplied.isEmpty {
                        StatusChip(text: "Learned", tone: .purple)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button("Paste") {
                    appState.pasteTranscript(item)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Copy") {
                    appState.copyTranscript(item)
                }

                Button("Correct") {
                    appState.openCorrectionEditor(for: item)
                }
            }
        }
        .padding(.vertical, 14)
    }
}

private struct VocabularyControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "Vocabulary",
                subtitle: "Names, acronyms, products, and phrases that should survive transcription cleanup."
            ) {
                Button("Save vocabulary") {
                    appState.savePersonalVocabulary()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            HeroPanel(
                title: "VoiceTypeMini spells the way you do.",
                subtitle: "Add one term per line. Use a vertical bar to teach spoken forms, like VoiceTypeMini | voice type mini.",
                iconName: "book.fill"
            ) {
                HStack(spacing: 8) {
                    ForEach(appState.personalVocabulary.prefix(5)) { entry in
                        StatusChip(text: entry.phrase, tone: .light)
                    }

                    if appState.personalVocabulary.isEmpty {
                        StatusChip(text: "Add names and jargon", tone: .light)
                    }
                }
            }

            PanelCard(title: "Personal terms", iconName: "text.quote") {
                TextEditor(text: $appState.personalVocabularyText)
                    .font(.body)
                    .frame(minHeight: 230)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VoiceTypeTheme.border, lineWidth: 1)
                    )

                HStack {
                    Button("Save vocabulary") {
                        appState.savePersonalVocabulary()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Clear vocabulary") {
                        appState.clearPersonalVocabulary()
                    }
                    .disabled(appState.personalVocabulary.isEmpty)
                }
            }
        }
    }
}

private struct CorrectionsControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "Corrections",
                subtitle: "Manual fixes become examples VoiceTypeMini can reuse during transcript cleanup."
            ) {
                Button("Clear corrections") {
                    appState.clearLearningCorrections()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(appState.correctionExamples.isEmpty)
            }

            PanelCard(title: "Learned fixes", iconName: "wand.and.stars") {
                if appState.correctionExamples.isEmpty {
                    EmptyStateText("No learned corrections yet. Use Correct & Learn after a transcript.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.correctionExamples) { example in
                            CorrectionExampleRow(example: example)

                            if example.id != appState.correctionExamples.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CorrectionExampleRow: View {
    let example: CorrectionExample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(example.createdAt, style: .date)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VoiceTypeTheme.muted)

                Spacer()

                StatusChip(text: example.backend, tone: .teal)
                if let target = example.targetApplication {
                    StatusChip(text: target, tone: .light)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                CorrectionTextBlock(title: "Heard", text: example.originalText)
                Image(systemName: "arrow.right")
                    .foregroundStyle(VoiceTypeTheme.muted)
                    .padding(.top, 23)
                CorrectionTextBlock(title: "Prefer", text: example.correctedText)
            }
        }
        .padding(.vertical, 14)
    }
}

private struct CorrectionTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(VoiceTypeTheme.muted)

            Text(text)
                .font(.callout)
                .foregroundStyle(VoiceTypeTheme.ink)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct TranscriptionControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "Transcription",
                subtitle: "Choose where speech is processed. WhisperKit is the local/private default; OpenAI is the cloud fallback."
            )

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(TranscriptionBackend.allCases) { backend in
                    BackendOptionCard(
                        backend: backend,
                        isSelected: appState.selectedBackend == backend
                    ) {
                        appState.selectedBackend = backend
                    }
                }
            }

            if appState.selectedBackend == .whisperKit {
                PanelCard(title: "WhisperKit model", iconName: "cpu") {
                    Picker("", selection: $appState.selectedWhisperModel) {
                        ForEach(WhisperKitModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(appState.selectedWhisperModel.description)
                        .font(.callout)
                        .foregroundStyle(VoiceTypeTheme.muted)
                }
            }

            PanelCard(title: "OpenAI fallback", iconName: "cloud") {
                SecureField("API key", text: $appState.openAIAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 460)

                HStack {
                    Button("Save OpenAI API Key") {
                        appState.saveOpenAIAPIKey()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!appState.hasOpenAIAPIKey)

                    Text("Used only when OpenAI is selected.")
                        .font(.callout)
                        .foregroundStyle(VoiceTypeTheme.muted)
                }
            }
        }
    }
}

private struct BackendOptionCard: View {
    let backend: TranscriptionBackend
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? VoiceTypeTheme.teal : VoiceTypeTheme.muted)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? VoiceTypeTheme.teal : VoiceTypeTheme.muted.opacity(0.5))
                }

                Text(backend.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text(backend.description)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? VoiceTypeTheme.teal : VoiceTypeTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch backend {
        case .whisperKit:
            return "cpu"
        case .appleSpeech:
            return "apple.logo"
        case .openAI:
            return "cloud"
        }
    }
}

private struct ShortcutsControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "Shortcuts",
                subtitle: "Pick the push-to-talk key that is easiest to hold while writing."
            )

            PanelCard(title: "Push-to-talk", iconName: "keyboard") {
                Picker("", selection: $appState.selectedPushToTalkHotkey) {
                    ForEach(appState.pushToTalkHotkeys) { hotkey in
                        Text(hotkey.displayName).tag(hotkey)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 420)

                Text(appState.hotkeyStatusText)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)

                if appState.selectedPushToTalkHotkey.displayName.contains("Fn") {
                    Text("Fn / Globe depends on macOS event delivery. If it feels inconsistent, use a Control or F-key shortcut and add diagnostics later.")
                        .font(.callout)
                        .foregroundStyle(VoiceTypeTheme.muted)
                        .padding(12)
                        .background(VoiceTypeTheme.warningSoft, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            PanelCard(title: "Dock commands", iconName: "rectangle.bottomthird.inset.filled") {
                ShortcutCommandRow(title: "Dictate", shortcut: "fn", detail: "Hold Fn / Globe or click the mic in the bottom dock.")
                Divider()
                ShortcutCommandRow(title: "Polish", shortcut: "⌥ Opt 1", detail: "Opens Correct & Learn for the latest transcript.")
                Divider()
                ShortcutCommandRow(title: "Scratchpad", shortcut: "hover / click", detail: "Opens a local note window for dictated fragments.")
            }
        }
    }
}

private struct ShortcutCommandRow: View {
    let title: String
    let shortcut: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
            }

            Spacer()

            Text(shortcut)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VoiceTypeTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(VoiceTypeTheme.border, lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }
}

private struct PermissionsControlCenterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderBlock(
                title: "Permissions",
                subtitle: "VoiceTypeMini needs microphone access to record, and macOS trust to insert text back into your apps."
            ) {
                Button("Refresh") {
                    appState.refreshInsertionStatus()
                    appState.refreshLaunchAtLoginStatus()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            PanelCard(title: "macOS setup", iconName: "lock.shield") {
                PermissionRow(
                    title: "Accessibility",
                    value: appState.permissionHealthText,
                    isHealthy: appState.hasAccessibilityPermission
                ) {
                    appState.openAccessibilitySettings()
                }

                Divider()

                PermissionRow(
                    title: "Input Monitoring",
                    value: "Needed for Fn / Globe and some paste flows.",
                    isHealthy: appState.hasAccessibilityPermission
                ) {
                    appState.openInputMonitoringSettings()
                }

                Divider()

                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { appState.isLaunchAtLoginEnabled },
                        set: { appState.setLaunchAtLoginEnabled($0) }
                    )
                )

                Text(appState.launchAtLoginStatusText)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
            }

            PanelCard(title: "Insertion behavior", iconName: "rectangle.and.pencil.and.ellipsis") {
                Picker("", selection: $appState.selectedInsertionMode) {
                    ForEach(appState.insertionModes) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(appState.selectedInsertionMode.description)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)

                Toggle("Preserve clipboard after inserting", isOn: $appState.preserveClipboard)
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let value: String
    let isHealthy: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            StatusDot(isHealthy: isHealthy)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text(value)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
            }

            Spacer()

            Button("Open") {
                action()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

private struct HeaderBlock<Action: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var action: Action

    init(title: String, subtitle: String, @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.action = action()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VoiceTypeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620, alignment: .leading)
            }

            Spacer()

            action
        }
    }
}

private struct HeroPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 13) {
                Text(title)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520, alignment: .leading)

                content
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 108, height: 108)

                Circle()
                    .stroke(.white.opacity(0.24), lineWidth: 1)
                    .frame(width: 108, height: 108)

                Image(systemName: iconName)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(red: 0.06, green: 0.17, blue: 0.19, alpha: 1)),
                    VoiceTypeTheme.teal,
                    Color(nsColor: NSColor(red: 0.40, green: 0.27, blue: 0.17, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let detail: String
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VoiceTypeTheme.teal)

                Spacer()
            }

            Text(value)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(VoiceTypeTheme.ink)

            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(VoiceTypeTheme.muted)

            Divider()

            Text(detail)
                .font(.callout)
                .foregroundStyle(VoiceTypeTheme.muted)
                .lineLimit(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(VoiceTypeTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VoiceTypeTheme.border, lineWidth: 1)
        )
    }
}

private struct PanelCard<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VoiceTypeTheme.teal)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VoiceTypeTheme.ink)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(VoiceTypeTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VoiceTypeTheme.border, lineWidth: 1)
        )
    }
}

private struct HealthRow: View {
    let title: String
    let value: String
    let isHealthy: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusDot(isHealthy: isHealthy)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(VoiceTypeTheme.ink)

                Text(value)
                    .font(.callout)
                    .foregroundStyle(VoiceTypeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StatusDot: View {
    let isHealthy: Bool

    var body: some View {
        Circle()
            .fill(isHealthy ? VoiceTypeTheme.teal : Color.orange)
            .frame(width: 9, height: 9)
    }
}

private enum StatusChipTone {
    case teal
    case light
    case purple
}

private struct StatusChip: View {
    let text: String
    let tone: StatusChipTone

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .teal:
            return VoiceTypeTheme.teal
        case .light:
            return VoiceTypeTheme.ink.opacity(0.82)
        case .purple:
            return Color.purple
        }
    }

    private var background: Color {
        switch tone {
        case .teal:
            return VoiceTypeTheme.tealSoft
        case .light:
            return Color.white.opacity(0.72)
        case .purple:
            return VoiceTypeTheme.purpleSoft
        }
    }
}

private struct EmptyStateText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(VoiceTypeTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                configuration.isPressed ? VoiceTypeTheme.ink.opacity(0.78) : VoiceTypeTheme.ink,
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VoiceTypeTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                configuration.isPressed ? Color.black.opacity(0.08) : Color.white.opacity(0.78),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(VoiceTypeTheme.border, lineWidth: 1)
            )
    }
}
