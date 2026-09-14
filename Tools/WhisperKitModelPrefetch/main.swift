import Foundation
import Darwin
@preconcurrency import WhisperKit

@main
struct WhisperKitModelPrefetch {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            try FileManager.default.createDirectory(
                at: options.outputDirectory,
                withIntermediateDirectories: true
            )

            for model in options.models {
                let modelFolder: URL
                if options.localOnly {
                    print("Using local WhisperKit model: \(model)")
                    modelFolder = try findCompleteModelFolder(for: model, under: options.outputDirectory)
                } else {
                    print("Downloading WhisperKit model: \(model)")
                    modelFolder = try await WhisperKit.download(
                        variant: model,
                        downloadBase: options.outputDirectory,
                        useBackgroundSession: true
                    )
                }

                print("\(options.load ? "Loading" : "Prewarming") WhisperKit model: \(model)")
                _ = try await WhisperKit(WhisperKitConfig(
                    model: model,
                    downloadBase: options.outputDirectory,
                    modelFolder: modelFolder.path,
                    verbose: false,
                    prewarm: !options.load,
                    load: options.load,
                    download: false,
                    useBackgroundDownloadSession: true
                ))

                print("Ready: \(modelFolder.path)")
            }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            let nsError = error as NSError
            fputs("Domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)\n", stderr)
            fputs(Options.usage, stderr)
            exit(1)
        }
    }

    private struct Options {
        var outputDirectory: URL
        var localOnly: Bool
        var load: Bool
        var models: [String]

        init(arguments: [String]) throws {
            var outputPath = "WhisperKitModels"
            var localOnly = false
            var load = false
            var models: [String] = []
            var index = 0

            while index < arguments.count {
                let argument = arguments[index]

                switch argument {
                case "--output":
                    index += 1
                    guard index < arguments.count else {
                        throw ValidationError("Missing value for --output.")
                    }
                    outputPath = arguments[index]
                case "--local-only":
                    localOnly = true
                case "--load":
                    load = true
                case "--help", "-h":
                    throw ValidationError(Options.usage)
                default:
                    models.append(argument)
                }

                index += 1
            }

            if models.isEmpty {
                models = ["base"]
            }

            outputDirectory = URL(fileURLWithPath: outputPath)
            self.localOnly = localOnly
            self.load = load
            self.models = models
        }

        static let usage = """

        Usage:
          swift run WhisperKitModelPrefetch --output WhisperKitModels base
          swift run WhisperKitModelPrefetch --output WhisperKitModels --load base
          swift run WhisperKitModelPrefetch --output WhisperKitModels --local-only --load base

        This downloads WhisperKit Core ML model weights into a local folder that
        Scripts/build-app.sh can bundle into VoiceTypeMini.app/Contents/Resources.

        """
    }

    private struct ValidationError: LocalizedError {
        var message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? {
            message
        }
    }

    private static func findCompleteModelFolder(for model: String, under root: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw ValidationError("Missing model directory: \(root.path)")
        }

        if isCompleteModelFolder(root) {
            return root
        }

        let modelNeedle = model.lowercased()
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )

        while let candidate = enumerator?.nextObject() as? URL {
            if candidate.pathComponents.contains(where: { $0.hasPrefix(".") }) {
                continue
            }

            guard let values = try? candidate.resourceValues(forKeys: keys),
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

        throw ValidationError("No complete local model folder found for \(model) under \(root.path).")
    }

    private static func isCompleteModelFolder(_ folder: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
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
}
