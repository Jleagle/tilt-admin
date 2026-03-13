// Sources/TiltAdminLib/Services/ConfigLoader.swift
import Foundation
import Yams

public enum ConfigError: Error, LocalizedError {
    case fileNotFound
    case parseError(String)
    case emptyConfig

    public var errorDescription: String? {
        switch self {
        case .fileNotFound: "Configuration file not found"
        case .parseError(let msg): "Failed to parse config: \(msg)"
        case .emptyConfig: "Configuration is empty or missing 'services' key"
        }
    }
}

public struct ConfigLoader {

    public static func parse(yaml: String) throws -> Config {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigError.emptyConfig
        }
        do {
            let config = try YAMLDecoder().decode(Config.self, from: yaml)
            return config
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }

    public static func load() throws -> Config {
        let path = try discoverConfigPath()
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: yaml)
    }

    public static func discoverConfigPath() throws -> String {
        let fm = FileManager.default
        let candidates = [
            fm.currentDirectoryPath + "/dependencies.yml",
            fm.currentDirectoryPath + "/dependencies.yaml",
            NSHomeDirectory() + "/.config/tilt-admin/config.yaml",
        ]
        for path in candidates {
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        throw ConfigError.fileNotFound
    }
}
