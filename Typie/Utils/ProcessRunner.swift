import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ProcessRunner {
    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 120
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Set up timeout
            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { proc in
                timeoutItem.cancel()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = ProcessResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: result)
            }
        }
    }
}
