import Foundation
import AppKit
import os

@MainActor
final class FunASRModelManager: ObservableObject {
    @Published private var operationStatuses: [String: PythonBackedModelStatus] = [:]

    let runtimeInstaller: PythonRuntimeInstaller
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "FunASRModelManager")

    init(runtimeInstaller: PythonRuntimeInstaller? = nil) {
        self.runtimeInstaller = runtimeInstaller ?? PythonRuntimeInstaller(
            environment: PythonRuntimeEnvironment(providerDirectoryName: "FunASR"),
            requiredPackages: ["funasr", "modelscope"],
            logCategory: "FunASRRuntime"
        )
    }

    func isRuntimeInstalled() -> Bool {
        runtimeInstaller.isRuntimeInstalled
    }

    func isModelDownloaded(named modelName: String) -> Bool {
        guard let model = TranscriptionModelRegistry.models.first(where: { $0.name == modelName }) as? FunASRModel else {
            return false
        }
        return isModelDownloaded(model)
    }

    func isModelDownloaded(_ model: FunASRModel) -> Bool {
        let directory = localModelDirectory(for: model)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return false
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return !contents.isEmpty
    }

    func isModelBusy(_ model: FunASRModel) -> Bool {
        operationStatuses[model.name] != nil || runtimeInstaller.installStatus != nil
    }

    func status(for model: FunASRModel) -> PythonBackedModelStatus? {
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
            logger.error("FunASR runtime install failed: \(error.localizedDescription, privacy: .public)")
            NotificationManager.shared.showNotification(title: error.localizedDescription, type: .error, duration: 5)
        }
    }

    func downloadModel(_ model: FunASRModel) async {
        guard !isModelDownloaded(model), operationStatuses[model.name] == nil else {
            return
        }

        operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 0.05, message: "Preparing FunASR...")
        defer {
            operationStatuses[model.name] = nil
            onModelsChanged?()
        }

        do {
            try await runtimeInstaller.ensureInstalled()
            try FileManager.default.createDirectory(at: runtimeInstaller.environment.modelsDirectory, withIntermediateDirectories: true)
            operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 0.35, message: "Downloading \(model.displayName)...")

            let helper = try runtimeInstaller.helperScript(named: "funasr_helper")
            let output = try await PythonProcessRunner.runPython(
                runtimeInstaller.environment.pythonExecutable,
                script: helper,
                arguments: [
                    "download",
                    "--model", model.modelScopeModel,
                    "--vad-model", model.vadModel,
                    "--punc-model", model.punctuationModel,
                    "--models-dir", runtimeInstaller.environment.modelsDirectory.path,
                    "--local-name", model.localDirectoryName
                ],
                timeout: 3600
            )

            guard output.exitStatus == 0 else {
                throw PythonRuntimeError.processFailed(command: "funasr_helper download", status: output.exitStatus, stderr: output.stderr)
            }
            operationStatuses[model.name] = PythonBackedModelStatus(fractionCompleted: 1.0, message: "Downloaded")
        } catch {
            logger.error("FunASR model download failed: \(error.localizedDescription, privacy: .public)")
            NotificationManager.shared.showNotification(title: error.localizedDescription, type: .error, duration: 5)
        }
    }

    func deleteModel(_ model: FunASRModel) {
        let directory = localModelDirectory(for: model)
        try? FileManager.default.removeItem(at: directory)
        onModelDeleted?(model.name)
        onModelsChanged?()
    }

    func showModelInFinder(_ model: FunASRModel) {
        let directory = localModelDirectory(for: model)
        if FileManager.default.fileExists(atPath: directory.path) {
            NSWorkspace.shared.selectFile(directory.path, inFileViewerRootedAtPath: "")
        }
    }

    func localModelDirectory(for model: FunASRModel) -> URL {
        runtimeInstaller.environment.modelsDirectory.appendingPathComponent(model.localDirectoryName, isDirectory: true)
    }
}
