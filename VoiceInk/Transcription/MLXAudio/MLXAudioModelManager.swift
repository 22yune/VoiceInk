import Foundation
import AppKit
import os

struct PythonBackedModelStatus {
    let fractionCompleted: Double
    let message: String
}

@MainActor
final class MLXAudioModelManager: ObservableObject {
    @Published private var operationStatuses: [String: PythonBackedModelStatus] = [:]

    let runtimeInstaller: PythonRuntimeInstaller
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "MLXAudioModelManager")

    init(runtimeInstaller: PythonRuntimeInstaller? = nil) {
        self.runtimeInstaller = runtimeInstaller ?? PythonRuntimeInstaller(
            environment: PythonRuntimeEnvironment(providerDirectoryName: "MLXAudio"),
            requiredPackages: ["mlx-audio[stt]", "modelscope"],
            logCategory: "MLXAudioRuntime"
        )
    }

    func isRuntimeInstalled() -> Bool {
        runtimeInstaller.isRuntimeInstalled
    }

    func isModelDownloaded(named modelName: String) -> Bool {
        guard let model = TranscriptionModelRegistry.models.first(where: { $0.name == modelName }) as? MLXAudioModel else {
            return false
        }
        return isModelDownloaded(model)
    }

    func isModelDownloaded(_ model: MLXAudioModel) -> Bool {
        let directory = localModelDirectory(for: model)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return false
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return !contents.isEmpty
    }

    func isModelBusy(_ model: MLXAudioModel) -> Bool {
        operationStatuses[model.name] != nil || runtimeInstaller.installStatus != nil
    }

    func status(for model: MLXAudioModel) -> PythonBackedModelStatus? {
        if let installStatus = runtimeInstaller.installStatus {
            return PythonBackedModelStatus(
                fractionCompleted: installStatus.fractionCompleted,
                message: installStatus.message
            )
        }
        return operationStatuses[model.name]
    }

    func installRuntime() async {
        do {
            try await runtimeInstaller.ensureInstalled()
            onModelsChanged?()
        } catch {
            logger.error("MLX Audio runtime install failed: \(error.localizedDescription, privacy: .public)")
            NotificationManager.shared.showNotification(title: error.localizedDescription, type: .error, duration: 5)
        }
    }

    func downloadModel(_ model: MLXAudioModel) async {
        guard SystemArchitecture.isAppleSilicon else {
            NotificationManager.shared.showNotification(title: "MLX Audio requires Apple Silicon", type: .error)
            return
        }
        guard !isModelDownloaded(model), operationStatuses[model.name] == nil else {
            return
        }

        operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 0.05, message: "Preparing MLX Audio...")
        defer {
            operationStatuses[model.name] = nil
            onModelsChanged?()
        }

        do {
            try await runtimeInstaller.ensureInstalled()
            try FileManager.default.createDirectory(at: runtimeInstaller.environment.modelsDirectory, withIntermediateDirectories: true)
            operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 0.35, message: "Downloading \(model.displayName)...")

            let helper = try runtimeInstaller.helperScript(named: "mlx_audio_helper")
            let output = try await PythonProcessRunner.runPython(
                runtimeInstaller.environment.pythonExecutable,
                script: helper,
                arguments: [
                    "download",
                    "--repo", model.modelScopeRepo,
                    "--models-dir", runtimeInstaller.environment.modelsDirectory.path,
                    "--local-name", model.localDirectoryName
                ],
                timeout: 3600
            )

            guard output.exitStatus == 0 else {
                throw PythonRuntimeError.processFailed(command: "mlx_audio_helper download", status: output.exitStatus, stderr: output.stderr)
            }
            operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 1.0, message: "Downloaded")
        } catch {
            logger.error("MLX Audio model download failed: \(error.localizedDescription, privacy: .public)")
            NotificationManager.shared.showNotification(title: error.localizedDescription, type: .error, duration: 5)
        }
    }

    func deleteModel(_ model: MLXAudioModel) {
        let directory = localModelDirectory(for: model)
        try? FileManager.default.removeItem(at: directory)
        onModelDeleted?(model.name)
        onModelsChanged?()
    }

    func showModelInFinder(_ model: MLXAudioModel) {
        let directory = localModelDirectory(for: model)
        if FileManager.default.fileExists(atPath: directory.path) {
            NSWorkspace.shared.selectFile(directory.path, inFileViewerRootedAtPath: "")
        }
    }

    func localModelDirectory(for model: MLXAudioModel) -> URL {
        runtimeInstaller.environment.modelsDirectory.appendingPathComponent(model.localDirectoryName, isDirectory: true)
    }
}
