import Foundation

struct PythonTranscriptionResult: Codable {
    let text: String
    let duration: Double?
}

struct PythonRuntimeEnvironment {
    let providerDirectoryName: String
    let appSupportDirectory: URL

    init(
        providerDirectoryName: String,
        appSupportDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk", isDirectory: true)
    ) {
        self.providerDirectoryName = providerDirectoryName
        self.appSupportDirectory = appSupportDirectory
    }

    var providerDirectory: URL {
        appSupportDirectory.appendingPathComponent(providerDirectoryName, isDirectory: true)
    }

    var virtualEnvironmentDirectory: URL {
        providerDirectory.appendingPathComponent("python-env", isDirectory: true)
    }

    var pythonExecutable: URL {
        virtualEnvironmentDirectory.appendingPathComponent("bin/python")
    }

    var modelsDirectory: URL {
        providerDirectory.appendingPathComponent("models", isDirectory: true)
    }
}

struct PythonProcessOutput {
    let stdout: String
    let stderr: String
    let exitStatus: Int32
}

enum PythonRuntimeError: Error, LocalizedError {
    case pythonNotFound
    case helperNotFound(String)
    case processFailed(command: String, status: Int32, stderr: String)
    case emptyTranscript
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found. Install Python 3, then try installing the local ASR runtime again."
        case .helperNotFound(let helper):
            return "VoiceInk could not find the \(helper) helper script."
        case .processFailed(let command, let status, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(command) failed with exit code \(status)."
            }
            return "\(command) failed with exit code \(status): \(detail)"
        case .emptyTranscript:
            return "The local ASR helper returned an empty transcript."
        case .invalidJSON(let output):
            return "The local ASR helper returned an invalid response: \(output)"
        }
    }
}
