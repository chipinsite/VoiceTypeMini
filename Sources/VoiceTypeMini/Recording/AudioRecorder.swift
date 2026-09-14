import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
    enum RecorderError: LocalizedError {
        case microphoneDenied
        case alreadyRecording
        case notRecording
        case missingInputFormat

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                return "Microphone permission is not granted."
            case .alreadyRecording:
                return "Recording is already running."
            case .notRecording:
                return "Recording is not running."
            case .missingInputFormat:
                return "Could not read the microphone input format."
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var meteringTimer: Timer?

    var onLevelChange: ((Double) -> Void)?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() async throws {
        guard !isRecording else {
            throw RecorderError.alreadyRecording
        }

        guard await requestMicrophoneAccess() else {
            throw RecorderError.microphoneDenied
        }

        try Task.checkCancellation()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeMini-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw RecorderError.missingInputFormat
        }

        self.recorder = recorder
        outputURL = url
        startMetering()
    }

    func stop() throws -> URL {
        guard isRecording, let outputURL else {
            throw RecorderError.notRecording
        }

        recorder?.stop()
        stopMetering()
        recorder = nil
        self.outputURL = nil

        return outputURL
    }

    func cancel() {
        recorder?.stop()
        stopMetering()
        recorder = nil
        outputURL = nil
    }

    func discard(_ url: URL?) {
        guard let url else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    private func startMetering() {
        stopMetering()
        onLevelChange?(0)

        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.publishMeterLevel()
            }
        }
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        onLevelChange?(0)
    }

    private func publishMeterLevel() {
        guard let recorder, recorder.isRecording else {
            onLevelChange?(0)
            return
        }

        recorder.updateMeters()
        let decibels = Double(recorder.averagePower(forChannel: 0))
        let clipped = max(-55, min(0, decibels))
        let normalized = pow(10, clipped / 35)
        onLevelChange?(max(0, min(1, normalized)))
    }
}
