import Foundation

enum PythonProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 900
    ) async throws -> PythonProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                if let environment {
                    process.environment = environment
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                var stdoutData = Data()
                var stderrData = Data()
                let outputLock = NSLock()

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    outputLock.lock()
                    stdoutData.append(data)
                    outputLock.unlock()
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    outputLock.lock()
                    stderrData.append(data)
                    outputLock.unlock()
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let semaphore = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in semaphore.signal() }

                if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                    if process.isRunning {
                        process.terminate()
                    }
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: PythonRuntimeError.processFailed(
                        command: executableURL.lastPathComponent,
                        status: -1,
                        stderr: "Timed out after \(Int(timeout)) seconds."
                    ))
                    return
                }

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                outputLock.lock()
                stdoutData.append(remainingStdout)
                stderrData.append(remainingStderr)
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                outputLock.unlock()

                continuation.resume(returning: PythonProcessOutput(
                    stdout: stdout,
                    stderr: stderr,
                    exitStatus: process.terminationStatus
                ))
            }
        }
    }

    static func runPython(
        _ pythonExecutable: URL,
        script: URL,
        arguments: [String],
        timeout: TimeInterval = 900
    ) async throws -> PythonProcessOutput {
        try await run(
            executableURL: pythonExecutable,
            arguments: [script.path] + arguments,
            environment: pythonEnvironment(for: pythonExecutable),
            timeout: timeout
        )
    }

    static func pythonEnvironment(for pythonExecutable: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let binDirectory = pythonExecutable.deletingLastPathComponent().path
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(binDirectory):\(existingPath)"
        environment["PYTHONNOUSERSITE"] = "1"
        return environment
    }
}
