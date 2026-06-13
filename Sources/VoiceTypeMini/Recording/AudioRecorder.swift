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
    }

    func stop() throws -> URL {
        guard isRecording, let outputURL else {
            throw RecorderError.notRecording
        }

        recorder?.stop()
        recorder = nil
        self.outputURL = nil

        return outputURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        outputURL = nil
    }

    func discard(_ url: URL?) {
        guard let url else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }
}
