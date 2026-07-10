// Sources/TiltAdminLib/Services/TiltLog.swift
import Foundation
import os

/// Logs tilt CLI invocations to the unified log (Console.app or
/// `log stream --predicate 'subsystem == "com.jleagle.tilt-admin"'`)
/// and mirrors each line to stderr so they are visible in the terminal
/// when running via `swift run TiltAdmin`.
enum TiltLog {
    private static let logger = Logger(subsystem: "com.jleagle.tilt-admin", category: "tilt-cli")

    static func command(_ line: String) {
        // .public: command lines would otherwise be redacted as <private> in log stream
        logger.log("\(line, privacy: .public)")
        mirror(line)
    }

    static func failure(_ line: String) {
        logger.error("\(line, privacy: .public)")
        mirror(line)
    }

    private static func mirror(_ line: String) {
        FileHandle.standardError.write(Data("[tilt] \(line)\n".utf8))
    }
}
