import Foundation
import Testing
@testable import VoiceInk

struct PythonTranscriptionBackendTests {
    @Test func modelRegistryContainsPythonBackedASRModels() {
        let names = Set(TranscriptionModelRegistry.models.map(\.name))

        #expect(names.contains("qwen3-asr-0.6b-8bit"))
        #expect(names.contains("qwen3-asr-1.7b-8bit"))
        #expect(names.contains("funasr-paraformer-zh"))
    }

    @Test func pythonBackedModelsExposeProviderMetadata() throws {
        let qwen = try #require(TranscriptionModelRegistry.models.first { $0.name == "qwen3-asr-0.6b-8bit" } as? MLXAudioModel)
        let funasr = try #require(TranscriptionModelRegistry.models.first { $0.name == "funasr-paraformer-zh" } as? FunASRModel)

        #expect(qwen.provider == .mlxAudio)
        #expect(qwen.modelScopeRepo == "mlx-community/Qwen3-ASR-0.6B-8bit")
        #expect(qwen.requiresAppleSilicon)
        #expect(funasr.provider == .funASR)
        #expect(funasr.modelScopeModel == "paraformer-zh")
        #expect(!funasr.requiresAppleSilicon)
        #expect(funasr.supportedLanguages == ["zh": "Chinese"])
    }

    @Test func pythonRuntimeEnvironmentUsesPrivateApplicationSupportDirectories() {
        let root = URL(fileURLWithPath: "/tmp/VoiceInk")
        let environment = PythonRuntimeEnvironment(providerDirectoryName: "MLXAudio", appSupportDirectory: root)

        #expect(environment.providerDirectory.path == "/tmp/VoiceInk/MLXAudio")
        #expect(environment.virtualEnvironmentDirectory.path == "/tmp/VoiceInk/MLXAudio/python-env")
        #expect(environment.pythonExecutable.path == "/tmp/VoiceInk/MLXAudio/python-env/bin/python")
        #expect(environment.modelsDirectory.path == "/tmp/VoiceInk/MLXAudio/models")
    }

    @Test func pythonTranscriptionResultDecodesHelperJSON() throws {
        let data = #"{"text":"你好，VoiceInk","duration":1.25}"#.data(using: .utf8)!

        let result = try JSONDecoder().decode(PythonTranscriptionResult.self, from: data)

        #expect(result.text == "你好，VoiceInk")
        #expect(result.duration == 1.25)
    }
}
