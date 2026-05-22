import Foundation
import os

final class MLXAudioTranscriptionService: TranscriptionService {
    private let modelManager: MLXAudioModelManager
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "MLXAudioTranscriptionService")

    @MainActor
    init(modelManager: MLXAudioModelManager) {
        self.modelManager = modelManager
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let mlxModel = model as? MLXAudioModel else {
            throw VoiceInkEngineError.transcriptionFailed
        }

        let (runtime, modelDirectory, helper): (PythonRuntimeInstaller, URL, URL) = try await MainActor.run {
            guard modelManager.isModelDownloaded(mlxModel) else {
                throw PythonRuntimeError.processFailed(command: "MLX Audio", status: 1, stderr: "\(mlxModel.displayName) is not downloaded.")
            }
            let runtime = modelManager.runtimeInstaller
            return (runtime, modelManager.localModelDirectory(for: mlxModel), try runtime.helperScript(named: "mlx_audio_helper"))
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
            logger.error("MLX Audio transcription failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
