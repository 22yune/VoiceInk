import Foundation
import os

struct PythonRuntimeInstallStatus {
    let fractionCompleted: Double
    let message: String
}

@MainActor
final class PythonRuntimeInstaller: ObservableObject {
    @Published private(set) var installStatus: PythonRuntimeInstallStatus?

    let environment: PythonRuntimeEnvironment
    private let requiredPackages: [String]
    private let logger: Logger

    init(environment: PythonRuntimeEnvironment, requiredPackages: [String], logCategory: String) {
        self.environment = environment
        self.requiredPackages = requiredPackages
        self.logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: logCategory)
    }

    var isRuntimeInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: environment.pythonExecutable.path)
            && FileManager.default.fileExists(atPath: installMarkerURL.path)
    }

    func ensureInstalled() async throws {
        if isRuntimeInstalled {
            return
        }
        defer {
            installStatus = nil
        }

        try FileManager.default.createDirectory(at: environment.providerDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: environment.modelsDirectory, withIntermediateDirectories: true)

        installStatus = PythonRuntimeInstallStatus(fractionCompleted: 0.1, message: "Finding Python 3...")
        let systemPython = try await findSystemPython()

        installStatus = PythonRuntimeInstallStatus(fractionCompleted: 0.25, message: "Creating private Python environment...")
        try await runChecked(
            executableURL: systemPython,
            arguments: ["-m", "venv", environment.virtualEnvironmentDirectory.path],
            commandName: "python3 -m venv",
            timeout: 180
        )

        installStatus = PythonRuntimeInstallStatus(fractionCompleted: 0.45, message: "Upgrading pip...")
        try await runChecked(
            executableURL: environment.pythonExecutable,
            arguments: ["-m", "pip", "install", "--upgrade", "pip"],
            commandName: "pip install --upgrade pip",
            timeout: 300
        )

        installStatus = PythonRuntimeInstallStatus(fractionCompleted: 0.65, message: "Installing local ASR packages...")
        try await runChecked(
            executableURL: environment.pythonExecutable,
            arguments: ["-m", "pip", "install"] + requiredPackages,
            commandName: "pip install \(requiredPackages.joined(separator: " "))",
            timeout: 1800
        )

        installStatus = PythonRuntimeInstallStatus(fractionCompleted: 1.0, message: "Runtime installed")
        try "ready".write(to: installMarkerURL, atomically: true, encoding: .utf8)
    }

    func helperScript(named name: String) throws -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: "py", subdirectory: "Python") {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: name, withExtension: "py") {
            return bundled
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Python/\(name).py")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }

        throw PythonRuntimeError.helperNotFound(name)
    }

    func decodeTranscriptionResult(from output: PythonProcessOutput) throws -> String {
        if output.exitStatus != 0 {
            throw PythonRuntimeError.processFailed(command: "python", status: output.exitStatus, stderr: output.stderr)
        }

        let trimmed = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw PythonRuntimeError.invalidJSON(trimmed)
        }

        do {
            let result = try JSONDecoder().decode(PythonTranscriptionResult.self, from: data)
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw PythonRuntimeError.emptyTranscript
            }
            return text
        } catch let runtimeError as PythonRuntimeError {
            throw runtimeError
        } catch {
            throw PythonRuntimeError.invalidJSON(trimmed)
        }
    }

    private func findSystemPython() async throws -> URL {
        let output = try await PythonProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-ilc", "echo __VOICEINK_PYTHON_START__; command -v python3; echo __VOICEINK_PYTHON_END__"],
            timeout: 10
        )

        guard output.exitStatus == 0 else {
            throw PythonRuntimeError.pythonNotFound
        }

        let path = extractMarkedValue(from: output.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw PythonRuntimeError.pythonNotFound
        }

        return URL(fileURLWithPath: path)
    }

    private var installMarkerURL: URL {
        environment.providerDirectory.appendingPathComponent(".voiceink-runtime-ready")
    }

    private func extractMarkedValue(from output: String) -> String {
        let startMarker = "__VOICEINK_PYTHON_START__"
        let endMarker = "__VOICEINK_PYTHON_END__"
        guard let start = output.range(of: startMarker),
              let end = output.range(of: endMarker, range: start.upperBound..<output.endIndex)
        else {
            return output
        }
        return String(output[start.upperBound..<end.lowerBound])
    }

    private func runChecked(
        executableURL: URL,
        arguments: [String],
        commandName: String,
        timeout: TimeInterval
    ) async throws {
        let output = try await PythonProcessRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            environment: PythonProcessRunner.pythonEnvironment(for: executableURL),
            timeout: timeout
        )

        guard output.exitStatus == 0 else {
            logger.error("\(commandName, privacy: .public) failed: \(output.stderr, privacy: .public)")
            throw PythonRuntimeError.processFailed(command: commandName, status: output.exitStatus, stderr: output.stderr)
        }
    }
}
