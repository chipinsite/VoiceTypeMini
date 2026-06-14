import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState
    @State private var hoveredItem: DockItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            if appState.isRecording {
                ActiveRecordingControl(
                    level: appState.audioLevel,
                    cancel: { appState.cancelDockDictation() },
                    confirm: { appState.finishPushToTalkRecording() }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else if shouldShowFullDock {
                VStack(spacing: 6) {
                    if let label = activeLabel {
                        DockLabel(text: label.title, shortcut: label.shortcut)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    HStack(spacing: 6) {
                        DockButton(
                            item: .dictate,
                            isHovered: hoveredItem == .dictate,
                            isPrimary: true,
                            isActive: appState.isRecording,
                            action: { appState.toggleDockDictation() },
                            hoveredItem: $hoveredItem
                        )

                        DockButton(
                            item: .polish,
                            isHovered: hoveredItem == .polish,
                            isPrimary: false,
                            isActive: false,
                            action: { appState.openCorrectionEditorForLastTranscript() },
                            hoveredItem: $hoveredItem
                        )

                        DockButton(
                            item: .scratchpad,
                            isHovered: hoveredItem == .scratchpad,
                            isPrimary: false,
                            isActive: false,
                            action: { appState.openScratchpad() },
                            hoveredItem: $hoveredItem
                        )
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.88), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 9)

                    if isStatusVisible {
                        Text(statusLine)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.72), in: Capsule())
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                IdleHandle()
                    .transition(.opacity)
            }
        }
        .frame(width: dockWidth, height: dockHeight, alignment: .bottom)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                if !appState.isRecording {
                    appState.isDockExpanded = hovering
                }
                if !hovering {
                    hoveredItem = nil
                }
            }
        }
    }

    private var shouldShowFullDock: Bool {
        appState.isDockExpanded || appState.shouldShowOverlay
    }

    private var dockWidth: CGFloat {
        if appState.isRecording {
            return 214
        }

        return shouldShowFullDock ? 292 : 86
    }

    private var dockHeight: CGFloat {
        if appState.isRecording {
            return 58
        }

        if shouldShowFullDock {
            return isStatusVisible ? 98 : 82
        }

        return 18
    }

    private var isStatusVisible: Bool {
        appState.shouldShowOverlay && !appState.isRecording
    }

    private var statusLine: String {
        appState.statusDetailText ?? appState.overlaySubtitle
    }

    private var activeLabel: DockLabelContent? {
        if appState.shouldShowOverlay {
            return DockLabelContent(title: appState.overlayTitle, shortcut: nil)
        }

        guard let hoveredItem else {
            return DockLabelContent(title: "Dictate", shortcut: shortcutText)
        }

        return DockLabelContent(title: hoveredItem.title, shortcut: hoveredItem.shortcut)
    }

    private var shortcutText: String {
        switch appState.selectedPushToTalkHotkey {
        case .fnKey:
            return "fn"
        default:
            return appState.selectedPushToTalkHotkey.displayName
        }
    }
}

private struct ActiveRecordingControl: View {
    let level: Double
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ActiveRecordingButton(
                systemName: "xmark",
                foreground: .white,
                background: .white.opacity(0.18),
                action: cancel
            )

            ActiveAudioWave(level: level)
                .frame(width: 82, height: 30)

            ActiveRecordingButton(
                systemName: "checkmark",
                foreground: .black,
                background: .white,
                action: confirm
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1)),
                    Color(nsColor: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 4)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}

private struct ActiveRecordingButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(background)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(foreground)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ActiveAudioWave: View {
    let level: Double

    private let multipliers: [CGFloat] = [
        0.42, 0.62, 0.86, 1.0, 0.78, 0.56,
        0.66, 0.92, 0.82, 0.58, 0.48, 0.36
    ]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(multipliers.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: barHeight(for: multipliers[index]))
            }
        }
        .frame(width: 82, height: 30)
        .accessibilityLabel("Microphone input level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private func barHeight(for multiplier: CGFloat) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        let quietHeight: CGFloat = 11
        let activeRange: CGFloat = 19
        return quietHeight + activeRange * normalizedLevel * multiplier
    }
}

private struct DockLabelContent {
    let title: String
    let shortcut: String?
}

private enum DockItem {
    case dictate
    case polish
    case scratchpad

    var title: String {
        switch self {
        case .dictate:
            return "Dictate"
        case .polish:
            return "Polish"
        case .scratchpad:
            return "Scratchpad"
        }
    }

    var shortcut: String? {
        switch self {
        case .dictate:
            return "fn"
        case .polish:
            return "⌥ Opt 1"
        case .scratchpad:
            return nil
        }
    }

    var iconName: String {
        switch self {
        case .dictate:
            return "mic.fill"
        case .polish:
            return "wand.and.stars"
        case .scratchpad:
            return "text.bubble"
        }
    }
}

private struct DockLabel: View {
    let text: String
    let shortcut: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)

            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(nsColor: NSColor(red: 0.96, green: 0.62, blue: 1.0, alpha: 1)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(.black.opacity(0.90), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
    }
}

private struct DockButton: View {
    let item: DockItem
    let isHovered: Bool
    let isPrimary: Bool
    let isActive: Bool
    let action: () -> Void
    @Binding var hoveredItem: DockItem?

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(background)
                    .frame(width: isPrimary ? 66 : 40, height: 40)

                Image(systemName: item.iconName)
                    .font(.system(size: isPrimary ? 20 : 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(
                Capsule()
                    .stroke(.white.opacity(isHovered || isActive ? 0.32 : 0.18), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                hoveredItem = hovering ? item : nil
            }
        }
    }

    private var background: Color {
        if isActive {
            return .red.opacity(0.92)
        }

        if isHovered {
            return Color(nsColor: NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1))
        }

        return .black.opacity(isPrimary ? 0.96 : 0.90)
    }
}

private struct IdleHandle: View {
    var body: some View {
        Capsule()
            .fill(.black.opacity(0.62))
            .frame(width: 70, height: 7)
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 4)
            .padding(.bottom, 4)
    }
}
