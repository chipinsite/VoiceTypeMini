import Foundation
@preconcurrency import WhisperKit

@MainActor
final class WhisperKitTranscriptionClient: TranscriptionClient {
    enum ClientError: LocalizedError {
        case missingTranscript
        case missingModelCacheDirectory

        var errorDescription: String? {
            switch self {
            case .missingTranscript:
                return "WhisperKit did not return transcript text."
            case .missingModelCacheDirectory:
                return "VoiceTypeMini could not create the local WhisperKit model cache."
            }
        }
    }

    private var model: String
    private var pipeline: WhisperKit?
    private var warmupTask: Task<Void, Never>?
    private var preparedModelFolder: URL?
    var onPreparationStatusChange: ((String) -> Void)?

    init(model: String = "tiny") {
        self.model = model
    }

    func setModel(_ model: String) {
        guard self.model != model else {
            return
        }

        self.model = model
        pipeline = nil
        preparedModelFolder = nil
        warmupTask?.cancel()
        warmupTask = nil
    }

    func warmUp() {
        guard pipeline == nil, warmupTask == nil else {
            return
        }

        warmupTask = Task { @MainActor in
            defer { warmupTask = nil }

            do {
                try await self.prepareForOfflineUse()
                _ = try await self.pipeline()
            } catch {
                pipeline = nil
                onPreparationStatusChange?("WhisperKit \(displayModelName): setup failed")
            }
        }
    }

    func prepareForOfflineUse() async throws {
        if let localFolder = try localModelFolder() {
            preparedModelFolder = localFolder
            onPreparationStatusChange?("WhisperKit \(displayModelName): local model ready")
            return
        }

        onPreparationStatusChange?("WhisperKit \(displayModelName): downloading model")
        let downloadedFolder = try await WhisperKit.download(
            variant: model,
            downloadBase: try modelCacheRoot(),
            useBackgroundSession: true
        )
        preparedModelFolder = downloadedFolder

        onPreparationStatusChange?("WhisperKit \(displayModelName): prewarming model")
        _ = try await WhisperKit(WhisperKitConfig(
            model: model,
            downloadBase: try modelCacheRoot(),
            modelFolder: downloadedFolder.path,
            verbose: false,
            prewarm: true,
            load: false,
            download: false,
            useBackgroundDownloadSession: true
        ))
        onPreparationStatusChange?("WhisperKit \(displayModelName): local model ready")
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let pipe = try await pipeline()
        let results = try await pipe.transcribe(audioPath: audioFileURL.path)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw ClientError.missingTranscript
        }

        return text
    }

    private func pipeline() async throws -> WhisperKit {
        if let pipeline {
            return pipeline
        }

        let localFolder: URL?
        if let preparedModelFolder {
            localFolder = preparedModelFolder
        } else {
            localFolder = try localModelFolder()
        }
        let newPipeline = try await WhisperKit(WhisperKitConfig(
            model: model,
            downloadBase: try modelCacheRoot(),
            modelFolder: localFolder?.path,
            verbose: false,
            prewarm: false,
            load: true,
            download: localFolder == nil,
            useBackgroundDownloadSession: true
        ))
        pipeline = newPipeline
        return newPipeline
    }

    private var displayModelName: String {
        model.prefix(1).uppercased() + model.dropFirst()
    }

    private func localModelFolder() throws -> URL? {
        if let preparedModelFolder, Self.isCompleteModelFolder(preparedModelFolder) {
            return preparedModelFolder
        }

        if let bundledRoot = Bundle.main.resourceURL?.appendingPathComponent(Self.bundledModelsDirectoryName, isDirectory: true),
           let bundledFolder = Self.findCompleteModelFolder(for: model, under: bundledRoot) {
            return bundledFolder
        }

        return Self.findCompleteModelFolder(for: model, under: try modelCacheRoot())
    }

    private func modelCacheRoot() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ClientError.missingModelCacheDirectory
        }

        let root = applicationSupport
            .appendingPathComponent("VoiceTypeMini", isDirectory: true)
            .appendingPathComponent(Self.bundledModelsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func findCompleteModelFolder(for model: String, under root: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return nil
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

        return nil
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

    private static let bundledModelsDirectoryName = "WhisperKitModels"
}
