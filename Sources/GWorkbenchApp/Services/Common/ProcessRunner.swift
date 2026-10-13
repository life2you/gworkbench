import Foundation

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let status: Int32
}

final class CommandOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maxBytes: Int
    private var data = Data()
    private var truncatedByteCount = 0

    init(maxBytes: Int = 1_048_576) {
        self.maxBytes = maxBytes
    }

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let remainingBytes = max(maxBytes - data.count, 0)
        if remainingBytes > 0 {
            data.append(contentsOf: chunk.prefix(remainingBytes))
        }
        if chunk.count > remainingBytes {
            truncatedByteCount += chunk.count - remainingBytes
        }
    }

    func stringValue() -> String {
        lock.lock()
        let capturedData = data
        let omittedBytes = truncatedByteCount
        lock.unlock()

        var value = String(decoding: capturedData, as: UTF8.self)
        if omittedBytes > 0 {
            value += "\n… output truncated (\(omittedBytes) bytes omitted)"
        }
        return value
    }
}

enum ProcessRunner {
    static func runCommand(
        _ command: String,
        arguments: [String],
        currentDirectory: String? = nil,
        allowFailure: Bool = false
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = CommandOutputBuffer()
        let stderrBuffer = CommandOutputBuffer()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            stdoutBuffer.append(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            stderrBuffer.append(handle.availableData)
        }

        try process.run()
        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderrBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        let stdout = stdoutBuffer.stringValue()
        let stderr = stderrBuffer.stringValue()
        let result = ShellResult(stdout: stdout, stderr: stderr, status: process.terminationStatus)

        if !allowFailure && result.status != 0 {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty
                ?? stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            throw WorkbenchError.message(detail.isEmpty ? "\(command) 执行失败" : detail)
        }

        return result
    }

    static func runGit(
        arguments: [String],
        currentDirectory: String? = nil,
        allowFailure: Bool = false
    ) throws -> ShellResult {
        try runCommand("git", arguments: arguments, currentDirectory: currentDirectory, allowFailure: allowFailure)
    }

    static func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: expandPath(path)).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
