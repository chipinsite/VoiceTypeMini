import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(appState.overlayTint)
                    .frame(width: 34, height: 34)

                Image(systemName: appState.overlayIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.overlayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(appState.overlaySubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if appState.isRecording {
                WaveformDotsView()

                Button {
                    appState.finishPushToTalkRecording()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 250, maxWidth: 520, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}

private struct WaveformDotsView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(Color.teal)
                    .frame(width: 4, height: isAnimating ? CGFloat(10 + index * 3) : CGFloat(18 - index * 2))
                    .animation(
                        .easeInOut(duration: 0.42)
                            .repeatForever()
                            .delay(Double(index) * 0.08),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 34, height: 24)
        .onAppear {
            isAnimating = true
        }
    }
}
