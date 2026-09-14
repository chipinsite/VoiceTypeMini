import Foundation
import NaturalLanguage
import Speech
@preconcurrency import WhisperKit

@main
struct TranscriptionBenchmark {
    static func main() async {
        do {
            let options = try BenchmarkOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            let runner = BenchmarkRunner(options: options)
            try await runner.run()
        } catch {
            fputs("Benchmark failed: \(error.localizedDescription)\n", stderr)
            BenchmarkOptions.printUsage()
            Foundation.exit(1)
        }
    }
}

struct BenchmarkOptions {
    let audioDirectory: URL
    let outputHTML: URL
    let engines: [BenchmarkEngine]
    let openAIAPIKey: String?
    let openAIModel: String
    let whisperKitModel: String

    init(arguments: [String]) throws {
        var audioDirectory: URL?
        var outputHTML = URL(fileURLWithPath: "Reports/transcription-benchmark.html")
        var engines: [BenchmarkEngine] = [.openAI, .appleSpeech, .whisperKit]
        var openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        var openAIModel = "gpt-4o-transcribe"
        var whisperKitModel = "base"

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            func nextValue() throws -> String {
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.missingArgumentValue(argument)
                }
                return arguments[index]
            }

            switch argument {
            case "--audio-dir":
                audioDirectory = URL(fileURLWithPath: try nextValue())
            case "--output":
                outputHTML = URL(fileURLWithPath: try nextValue())
            case "--engines":
                engines = try nextValue()
                    .split(separator: ",")
                    .map { try BenchmarkEngine(rawName: String($0)) }
            case "--openai-key":
                openAIAPIKey = try nextValue()
            case "--openai-model":
                openAIModel = try nextValue()
            case "--whisperkit-model":
                whisperKitModel = try nextValue()
            case "--help", "-h":
                Self.printUsage()
                Foundation.exit(0)
            default:
                throw BenchmarkError.unknownArgument(argument)
            }

            index += 1
        }

        guard let audioDirectory else {
            throw BenchmarkError.missingAudioDirectory
        }

        self.audioDirectory = audioDirectory
        self.outputHTML = outputHTML
        self.engines = engines
        self.openAIAPIKey = openAIAPIKey
        self.openAIModel = openAIModel
        self.whisperKitModel = whisperKitModel
    }

    static func printUsage() {
        print(
            """
            Usage:
              swift run TranscriptionBenchmark --audio-dir Benchmarks/Samples

            Options:
              --audio-dir PATH                 Folder containing .m4a, .wav, .caf, or .mp3 files.
              --output PATH                    HTML report path. Default: Reports/transcription-benchmark.html
              --engines LIST                   Comma list: openai,apple,whisperkit
              --openai-key KEY                 OpenAI key. Defaults to OPENAI_API_KEY.
              --openai-model MODEL             Default: gpt-4o-transcribe
              --whisperkit-model MODEL         Default: base

            References:
              Add a .txt file next to each audio file with the same base name.
              Example: intro.m4a and intro.txt
            """
        )
    }
}

enum BenchmarkEngine: String, Codable, CaseIterable {
    case openAI
    case appleSpeech
    case whisperKit

    init(rawName: String) throws {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "openai", "open-ai":
            self = .openAI
        case "apple", "apple-speech", "applespeech":
            self = .appleSpeech
        case "whisperkit", "whisper-kit":
            self = .whisperKit
        default:
            throw BenchmarkError.unknownEngine(rawName)
        }
    }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .appleSpeech:
            return "Apple Speech"
        case .whisperKit:
            return "WhisperKit"
        }
    }
}

enum BenchmarkError: LocalizedError {
    case missingAudioDirectory
    case missingArgumentValue(String)
    case unknownArgument(String)
    case unknownEngine(String)
    case noAudioFiles(URL)
    case missingOpenAIAPIKey
    case invalidResponse
    case requestFailed(Int, String)
    case missingTranscript

    var errorDescription: String? {
        switch self {
        case .missingAudioDirectory:
            return "Add --audio-dir with a folder of benchmark recordings."
        case let .missingArgumentValue(argument):
            return "\(argument) needs a value."
        case let .unknownArgument(argument):
            return "Unknown argument: \(argument)"
        case let .unknownEngine(engine):
            return "Unknown engine: \(engine)"
        case let .noAudioFiles(directory):
            return "No supported audio files found in \(directory.path)."
        case .missingOpenAIAPIKey:
            return "OpenAI benchmark needs --openai-key or OPENAI_API_KEY."
        case .invalidResponse:
            return "The transcription service returned an invalid response."
        case let .requestFailed(statusCode, body):
            return "Request failed with HTTP \(statusCode): \(body)"
        case .missingTranscript:
            return "No transcript text was returned."
        }
    }
}

struct BenchmarkSample: Codable {
    let audioURL: URL
    let referenceText: String?

    var name: String {
        audioURL.deletingPathExtension().lastPathComponent
    }
}

struct BenchmarkResult: Codable {
    let sampleName: String
    let audioPath: String
    let engine: BenchmarkEngine
    let transcript: String?
    let referenceText: String?
    let wordErrorRate: Double?
    let durationSeconds: Double
    let errorMessage: String?
}

@MainActor
final class BenchmarkRunner {
    private let options: BenchmarkOptions

    init(options: BenchmarkOptions) {
        self.options = options
    }

    func run() async throws {
        let samples = try loadSamples()
        try FileManager.default.createDirectory(
            at: options.outputHTML.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var results: [BenchmarkResult] = []
        for sample in samples {
            print("Sample: \(sample.name)")
            for engine in options.engines {
                let result = await run(engine: engine, sample: sample)
                results.append(result)
                let status = result.errorMessage.map { "failed: \($0)" } ?? "ok"
                print("  \(engine.displayName): \(status)")
            }
        }

        try writeJSON(results)
        try writeHTML(results, samples: samples)
        print("Report written to \(options.outputHTML.path)")
    }

    private func loadSamples() throws -> [BenchmarkSample] {
        let supportedExtensions = Set(["m4a", "wav", "caf", "mp3"])
        let files = try FileManager.default.contentsOfDirectory(
            at: options.audioDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let audioFiles = files
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !audioFiles.isEmpty else {
            throw BenchmarkError.noAudioFiles(options.audioDirectory)
        }

        return audioFiles.map { audioURL in
            let referenceURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
            let referenceText = try? String(contentsOf: referenceURL, encoding: .utf8).trimmedForScoring
            return BenchmarkSample(audioURL: audioURL, referenceText: referenceText?.isEmpty == true ? nil : referenceText)
        }
    }

    private func run(engine: BenchmarkEngine, sample: BenchmarkSample) async -> BenchmarkResult {
        let start = Date()
        do {
            let transcript: String
            switch engine {
            case .openAI:
                transcript = try await transcribeWithOpenAI(sample.audioURL)
            case .appleSpeech:
                transcript = try await transcribeWithAppleSpeech(sample.audioURL)
            case .whisperKit:
                transcript = try await transcribeWithWhisperKit(sample.audioURL)
            }

            let elapsed = Date().timeIntervalSince(start)
            return BenchmarkResult(
                sampleName: sample.name,
                audioPath: sample.audioURL.path,
                engine: engine,
                transcript: transcript,
                referenceText: sample.referenceText,
                wordErrorRate: sample.referenceText.map { WordErrorRate.score(reference: $0, hypothesis: transcript) },
                durationSeconds: elapsed,
                errorMessage: nil
            )
        } catch {
            return BenchmarkResult(
                sampleName: sample.name,
                audioPath: sample.audioURL.path,
                engine: engine,
                transcript: nil,
                referenceText: sample.referenceText,
                wordErrorRate: nil,
                durationSeconds: Date().timeIntervalSince(start),
                errorMessage: error.localizedDescription
            )
        }
    }

    private func transcribeWithOpenAI(_ audioURL: URL) async throws -> String {
        guard let apiKey = options.openAIAPIKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BenchmarkError.missingOpenAIAPIKey
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(fileURL: audioURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BenchmarkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BenchmarkError.requestFailed(
                httpResponse.statusCode,
                String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            )
        }

        let decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
        let text = decoded.text.trimmedForScoring
        guard !text.isEmpty else {
            throw BenchmarkError.missingTranscript
        }

        return text
    }

    private func multipartBody(fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let fileData = try Data(contentsOf: fileURL)

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"model\"\(lineBreak)\(lineBreak)")
        body.appendString("\(options.openAIModel)\(lineBreak)")

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\(lineBreak)")
        body.appendString("Content-Type: \(contentType(for: fileURL))\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.appendString(lineBreak)

        body.appendString("--\(boundary)--\(lineBreak)")
        return body
    }

    private func contentType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "caf":
            return "audio/x-caf"
        default:
            return "application/octet-stream"
        }
    }

    private func transcribeWithAppleSpeech(_ audioURL: URL) async throws -> String {
        try await requestSpeechAuthorization()
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            throw BenchmarkError.missingTranscript
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            var task: SFSpeechRecognitionTask?

            func finish(_ result: Result<String, Error>) {
                guard !didResume else {
                    return
                }

                didResume = true
                task?.cancel()
                continuation.resume(with: result)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    finish(.failure(error))
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                let text = result.bestTranscription.formattedString.trimmedForScoring
                if text.isEmpty {
                    finish(.failure(BenchmarkError.missingTranscript))
                } else {
                    finish(.success(text))
                }
            }
        }
    }

    private func requestSpeechAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            guard status == .authorized else {
                throw BenchmarkError.requestFailed(0, "Speech recognition permission was not granted.")
            }
        case .denied, .restricted:
            throw BenchmarkError.requestFailed(0, "Speech recognition permission is denied or restricted.")
        @unknown default:
            throw BenchmarkError.requestFailed(0, "Speech recognition permission is unavailable.")
        }
    }

    @MainActor
    private func transcribeWithWhisperKit(_ audioURL: URL) async throws -> String {
        let modelFolder = findWhisperKitModelFolder(named: options.whisperKitModel)
        let pipeline = try await WhisperKit(WhisperKitConfig(
            model: options.whisperKitModel,
            downloadBase: try applicationSupportModelRoot(),
            modelFolder: modelFolder?.path,
            verbose: false,
            prewarm: false,
            load: true,
            download: modelFolder == nil,
            useBackgroundDownloadSession: true
        ))
        let results = try await pipeline.transcribe(audioPath: audioURL.path)
        let text = results.map { $0.text }.joined(separator: " ").trimmedForScoring
        guard !text.isEmpty else {
            throw BenchmarkError.missingTranscript
        }
        return text
    }

    private func applicationSupportModelRoot() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let directory = root
            .appendingPathComponent("VoiceTypeMini", isDirectory: true)
            .appendingPathComponent("WhisperKitModels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func findWhisperKitModelFolder(named model: String) -> URL? {
        let candidates = [
            URL(fileURLWithPath: "WhisperKitModels"),
            URL(fileURLWithPath: "/Applications/VoiceTypeMini.app/Contents/Resources/WhisperKitModels")
        ]

        for root in candidates where FileManager.default.fileExists(atPath: root.path) {
            if let match = findCompleteModelFolder(named: model, under: root) {
                return match
            }
        }

        return nil
    }

    private func findCompleteModelFolder(named model: String, under root: URL) -> URL? {
        let modelNeedle = model.lowercased()
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsPackageDescendants]
        )

        while let candidate = enumerator?.nextObject() as? URL {
            if candidate.pathComponents.contains(where: { $0.hasPrefix(".") }) {
                continue
            }

            guard let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey]),
                  values.isDirectory == true,
                  values.isHidden != true,
                  isCompleteModelFolder(candidate) else {
                continue
            }

            let name = candidate.lastPathComponent.lowercased()
            if name == modelNeedle || name.contains(modelNeedle) {
                return candidate
            }
        }

        return nil
    }

    private func isCompleteModelFolder(_ folder: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let names = contents.map(\.lastPathComponent)
        return ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { requiredName in
            names.contains { name in
                name.hasPrefix(requiredName)
                    && (name.hasSuffix(".mlmodelc") || name.hasSuffix(".mlpackage"))
            }
        }
    }

    private func writeJSON(_ results: [BenchmarkResult]) throws {
        let jsonURL = options.outputHTML.deletingPathExtension().appendingPathExtension("json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(results)
        try data.write(to: jsonURL, options: [.atomic])
    }

    private func writeHTML(_ results: [BenchmarkResult], samples: [BenchmarkSample]) throws {
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let rows = results.map { result in
            """
            <tr>
              <td>\(escape(result.sampleName))</td>
              <td>\(escape(result.engine.displayName))</td>
              <td>\(result.wordErrorRate.map { String(format: "%.1f%%", $0 * 100) } ?? "No reference")</td>
              <td>\(String(format: "%.2fs", result.durationSeconds))</td>
              <td>\(escape(result.transcript ?? ""))</td>
              <td>\(escape(result.errorMessage ?? ""))</td>
            </tr>
            """
        }.joined(separator: "\n")

        let summaryRows = options.engines.map { engine in
            let engineResults = results.filter { $0.engine == engine }
            let scored = engineResults.compactMap(\.wordErrorRate)
            let averageWER = scored.isEmpty ? nil : scored.reduce(0, +) / Double(scored.count)
            let failures = engineResults.filter { $0.errorMessage != nil }.count
            return """
            <tr>
              <td>\(escape(engine.displayName))</td>
              <td>\(averageWER.map { String(format: "%.1f%%", $0 * 100) } ?? "No references")</td>
              <td>\(failures)</td>
            </tr>
            """
        }.joined(separator: "\n")

        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>VoiceTypeMini Transcription Benchmark</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; color: #18201f; background: #fbfcfb; }
            main { max-width: 1180px; margin: 0 auto; padding: 42px 26px 72px; }
            h1 { font-size: 42px; margin: 0 0 8px; }
            h2 { margin-top: 34px; padding-top: 24px; border-top: 1px solid #d8dfdc; }
            p { color: #5d6865; }
            table { width: 100%; border-collapse: collapse; background: white; border: 1px solid #d8dfdc; }
            th, td { text-align: left; vertical-align: top; padding: 10px 12px; border-bottom: 1px solid #d8dfdc; }
            th { background: #f4f7f5; }
            td:nth-child(5) { min-width: 360px; }
            .small { font-size: 14px; color: #5d6865; }
          </style>
        </head>
        <body>
        <main>
          <h1>VoiceTypeMini Transcription Benchmark</h1>
          <p>Generated \(escape(generatedAt)). Samples: \(samples.count). Engines: \(options.engines.map { $0.displayName }.joined(separator: ", ")).</p>

          <h2>Summary</h2>
          <table>
            <thead><tr><th>Engine</th><th>Average word error rate</th><th>Failures</th></tr></thead>
            <tbody>\(summaryRows)</tbody>
          </table>

          <h2>Detailed Results</h2>
          <table>
            <thead><tr><th>Sample</th><th>Engine</th><th>Word error rate</th><th>Time</th><th>Transcript</th><th>Error</th></tr></thead>
            <tbody>\(rows)</tbody>
          </table>

          <p class="small">Lower word error rate is better. Add a same-name .txt reference next to each audio file for scoring.</p>
        </main>
        </body>
        </html>
        """

        try html.write(to: options.outputHTML, atomically: true, encoding: String.Encoding.utf8)
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    let text: String
}

enum WordErrorRate {
    static func score(reference: String, hypothesis: String) -> Double {
        let referenceWords = words(reference)
        let hypothesisWords = words(hypothesis)
        guard !referenceWords.isEmpty else {
            return hypothesisWords.isEmpty ? 0 : 1
        }

        let distance = levenshtein(referenceWords, hypothesisWords)
        return Double(distance) / Double(referenceWords.count)
    }

    private static func words(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalized
        return tokenizer.tokens(for: normalized.startIndex..<normalized.endIndex)
            .map { String(normalized[$0]) }
    }

    private static func levenshtein(_ source: [String], _ target: [String]) -> Int {
        guard !source.isEmpty else { return target.count }
        guard !target.isEmpty else { return source.count }
        var previous = Array(0...target.count)
        var current = Array(repeating: 0, count: target.count + 1)

        for sourceIndex in 1...source.count {
            current[0] = sourceIndex
            for targetIndex in 1...target.count {
                let substitutionCost = source[sourceIndex - 1] == target[targetIndex - 1] ? 0 : 1
                current[targetIndex] = min(
                    previous[targetIndex] + 1,
                    current[targetIndex - 1] + 1,
                    previous[targetIndex - 1] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[target.count]
    }
}

private extension String {
    var trimmedForScoring: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
