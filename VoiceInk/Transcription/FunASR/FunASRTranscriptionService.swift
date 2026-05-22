import Foundation
import os

final class FunASRTranscriptionService: TranscriptionService {
    private let modelManager: FunASRModelManager
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "FunASRTranscriptionService")

    @MainActor
    init(modelManager: FunASRModelManager) {
        self.modelManager = modelManager
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let funASRModel = model as? FunASRModel else {
            throw VoiceInkEngineError.transcriptionFailed
        }

        let (runtime, modelDirectory, helper): (PythonRuntimeInstaller, URL, URL) = try await MainActor.run {
            guard modelManager.isModelDownloaded(funASRModel) else {
                throw PythonRuntimeError.processFailed(command: "FunASR", status: 1, stderr: "\(funASRModel.displayName) is not downloaded.")
            }
            let runtime = modelManager.runtimeInstaller
            return (runtime, modelManager.localModelDirectory(for: funASRModel), try runtime.helperScript(named: "funasr_helper"))
        }

        let output = try await PythonProcessRunner.runPython(
            runtime.environment.pythonExecutable,
            script: helper,
            arguments: [
                "transcribe",
                "--model-dir", modelDirectory.path,
                "--audio", audioURL.path
            ],
            timeout: 1800
        )

        do {
            return try await MainActor.run {
                try runtime.decodeTranscriptionResult(from: output)
            }
        } catch {
            logger.error("FunASR transcription failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
