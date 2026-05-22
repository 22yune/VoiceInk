import SwiftUI
import AppKit

struct ModelCardView: View {
    let model: any TranscriptionModel
    let fluidAudioModelManager: FluidAudioModelManager
    let mlxAudioModelManager: MLXAudioModelManager
    let funASRModelManager: FunASRModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let isDownloaded: Bool
    let isCurrent: Bool
    let downloadProgress: [String: Double]
    let modelURL: URL?
    let isWarming: Bool

    // Actions
    var deleteAction: () -> Void
    var setDefaultAction: () -> Void
    var downloadAction: () -> Void
    var editAction: ((CustomCloudModel) -> Void)?
    var body: some View {
        Group {
            switch model.provider {
            case .whisper:
                if let whisperModel = model as? WhisperModel {
                    WhisperModelCardView(
                        model: whisperModel,
                        isDownloaded: isDownloaded,
                        isCurrent: isCurrent,
                        downloadProgress: downloadProgress,
                        modelURL: modelURL,
                        isWarming: isWarming,
                        deleteAction: deleteAction,
                        setDefaultAction: setDefaultAction,
                        downloadAction: downloadAction
                    )
                } else if let importedModel = model as? ImportedWhisperModel {
                    ImportedWhisperModelCardView(
                        model: importedModel,
                        isDownloaded: isDownloaded,
                        isCurrent: isCurrent,
                        modelURL: modelURL,
                        deleteAction: deleteAction,
                        setDefaultAction: setDefaultAction
                    )
                }
            case .fluidAudio:
                if let fluidAudioModel = model as? FluidAudioModel {
                    FluidAudioModelCardView(
                        model: fluidAudioModel,
                        fluidAudioModelManager: fluidAudioModelManager,
                        transcriptionModelManager: transcriptionModelManager
                    )
                }
            case .nativeApple:
                if let nativeAppleModel = model as? NativeAppleModel {
                    NativeAppleModelCardView(
                        model: nativeAppleModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction
                    )
                }
            case .mlxAudio:
                if let mlxAudioModel = model as? MLXAudioModel {
                    PythonLocalModelCardView(
                        displayName: mlxAudioModel.displayName,
                        language: mlxAudioModel.language,
                        size: mlxAudioModel.size,
                        description: mlxAudioModel.description,
                        speed: mlxAudioModel.speed,
                        accuracy: mlxAudioModel.accuracy,
                        ramUsage: mlxAudioModel.ramUsage,
                        requiresAppleSilicon: mlxAudioModel.requiresAppleSilicon,
                        isRuntimeInstalled: mlxAudioModelManager.isRuntimeInstalled(),
                        isDownloaded: mlxAudioModelManager.isModelDownloaded(mlxAudioModel),
                        isCurrent: isCurrent,
                        isBusy: mlxAudioModelManager.isModelBusy(mlxAudioModel),
                        status: mlxAudioModelManager.status(for: mlxAudioModel),
                        installRuntimeAction: {
                            Task { await mlxAudioModelManager.installRuntime() }
                        },
                        downloadAction: {
                            Task { await mlxAudioModelManager.downloadModel(mlxAudioModel) }
                        },
                        setDefaultAction: setDefaultAction,
                        deleteAction: {
                            mlxAudioModelManager.deleteModel(mlxAudioModel)
                        },
                        showInFinderAction: {
                            mlxAudioModelManager.showModelInFinder(mlxAudioModel)
                        }
                    )
                }
            case .funASR:
                if let funASRModel = model as? FunASRModel {
                    PythonLocalModelCardView(
                        displayName: funASRModel.displayName,
                        language: funASRModel.language,
                        size: funASRModel.size,
                        description: funASRModel.description,
                        speed: funASRModel.speed,
                        accuracy: funASRModel.accuracy,
                        ramUsage: funASRModel.ramUsage,
                        requiresAppleSilicon: funASRModel.requiresAppleSilicon,
                        isRuntimeInstalled: funASRModelManager.isRuntimeInstalled(),
                        isDownloaded: funASRModelManager.isModelDownloaded(funASRModel),
                        isCurrent: isCurrent,
                        isBusy: funASRModelManager.isModelBusy(funASRModel),
                        status: funASRModelManager.status(for: funASRModel),
                        installRuntimeAction: {
                            Task { await funASRModelManager.installRuntime() }
                        },
                        downloadAction: {
                            Task { await funASRModelManager.downloadModel(funASRModel) }
                        },
                        setDefaultAction: setDefaultAction,
                        deleteAction: {
                            funASRModelManager.deleteModel(funASRModel)
                        },
                        showInFinderAction: {
                            funASRModelManager.showModelInFinder(funASRModel)
                        }
                    )
                }
            case .custom:
                if let customModel = model as? CustomCloudModel {
                    CustomModelCardView(
                        model: customModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction,
                        deleteAction: deleteAction,
                        editAction: editAction ?? { _ in }
                    )
                }
            default:
                if let cloudModel = model as? CloudModel {
                    CloudModelCardView(
                        model: cloudModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction
                    )
                }
            }
        }
    }
}
