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

    public init() {}

    public func checkInstalled() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "tilt"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
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
        guard !names.isEmpty else { return }
        try await runTilt(arguments: ["enable"] + names)
    }

    public func disableServices(_ names: [String]) async throws {
        guard !names.isEmpty else { return }
        try await runTilt(arguments: ["disable"] + names)
    }

    @discardableResult
    private func runTilt(arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tilt"] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let pid = process.processIdentifier
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeoutSeconds))
            kill(pid, SIGTERM)
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            if process.terminationStatus == 15 { // SIGTERM
                throw TiltError.timeout
            }
            throw TiltError.commandFailed(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }
}
