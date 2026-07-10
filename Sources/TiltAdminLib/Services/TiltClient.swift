import Foundation

public enum TiltError: Error, LocalizedError {
    case notInstalled
    case commandFailed(String)
    case timeout
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled: "Tilt CLI not found. Ensure 'tilt' is in your PATH."
        case .commandFailed(let msg): "Tilt command failed: \(msg)"
        case .timeout: "Tilt command timed out (10s)"
        case .parseError(let msg): "Failed to parse Tilt output: \(msg)"
        }
    }
}

public actor TiltClient {
    private let timeoutSeconds: Double = 10
    private let tiltPath: String?

    public init() {
        self.tiltPath = Self.findTilt()
    }

    /// Search common locations for the tilt binary since GUI apps have a minimal PATH.
    private static func findTilt() -> String? {
        let candidates = [
            "/opt/homebrew/bin/tilt",
            "/usr/local/bin/tilt",
            "/usr/bin/tilt",
            NSHomeDirectory() + "/.local/bin/tilt",
            NSHomeDirectory() + "/go/bin/tilt",
        ]
        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fallback: try to resolve via user's login shell
        if let shellPath = Self.resolveViaShell() {
            return shellPath
        }
        return nil
    }

    private static func resolveViaShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "which tilt"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        } catch {}
        return nil
    }

    public func checkInstalled() throws {
        guard tiltPath != nil else {
            throw TiltError.notInstalled
        }
    }

    public func fetchResources() async throws -> [UIResource] {
        let output = try await runTilt(arguments: ["get", "uiresource", "-o", "json"])
        guard let data = output.data(using: .utf8) else {
            throw TiltError.parseError("Invalid UTF-8 output")
        }
        do {
            let list = try JSONDecoder().decode(UIResourceList.self, from: data)
            return list.items
        } catch {
            throw TiltError.parseError(error.localizedDescription)
        }
    }

    public func enableServices(_ names: [String]) async throws {
        try await runLoggedTilt(arguments: ["enable"] + names)
    }

    public func disableServices(_ names: [String]) async throws {
        try await runLoggedTilt(arguments: ["disable"] + names)
    }

    /// Runs a state-changing tilt command, logging the command line and any failure.
    /// The status poll (fetchResources) deliberately bypasses this to keep logs quiet.
    private func runLoggedTilt(arguments: [String]) async throws {
        guard arguments.count > 1 else { return }
        let command = (["tilt"] + arguments).joined(separator: " ")
        TiltLog.command(command)
        do {
            try await runTilt(arguments: arguments)
        } catch {
            TiltLog.failure("\(command) — \(error.localizedDescription)")
            throw error
        }
    }

    @discardableResult
    private nonisolated func runTilt(arguments: [String]) async throws -> String {
        guard let tiltPath else { throw TiltError.notInstalled }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tiltPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Collect pipe data in background to avoid deadlock when output is large
        var outData = Data()
        var errData = Data()
        let outHandle = stdoutPipe.fileHandleForReading
        let errHandle = stderrPipe.fileHandleForReading

        try process.run()

        let pid = process.processIdentifier
        let timeout = self.timeoutSeconds

        // Read stdout/stderr concurrently, then wait for termination
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                outData = outHandle.readDataToEndOfFile()
            }
            DispatchQueue.global().async {
                errData = errHandle.readDataToEndOfFile()
            }

            process.terminationHandler = { proc in
                // Give pipe reads a moment to finish
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    if proc.terminationStatus != 0 {
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        if proc.terminationStatus == 15 {
                            continuation.resume(throwing: TiltError.timeout)
                        } else {
                            continuation.resume(throwing: TiltError.commandFailed(errMsg.trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    } else {
                        continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                    }
                }
            }

            // Timeout
            Task {
                try await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    kill(pid, SIGTERM)
                }
            }
        }
    }
}
