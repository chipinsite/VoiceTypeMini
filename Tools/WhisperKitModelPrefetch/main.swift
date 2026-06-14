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
                print("Downloading WhisperKit model: \(model)")
                let modelFolder = try await WhisperKit.download(
                    variant: model,
                    downloadBase: options.outputDirectory,
                    useBackgroundSession: true
                )

                print("Prewarming WhisperKit model: \(model)")
                _ = try await WhisperKit(WhisperKitConfig(
                    model: model,
                    downloadBase: options.outputDirectory,
                    modelFolder: modelFolder.path,
                    verbose: false,
                    prewarm: true,
                    load: false,
                    download: false,
                    useBackgroundDownloadSession: true
                ))

                print("Ready: \(modelFolder.path)")
            }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            fputs(Options.usage, stderr)
            exit(1)
        }
    }

    private struct Options {
        var outputDirectory: URL
        var models: [String]

        init(arguments: [String]) throws {
            var outputPath = "WhisperKitModels"
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
            self.models = models
        }

        static let usage = """

        Usage:
          swift run WhisperKitModelPrefetch --output WhisperKitModels base

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
}
