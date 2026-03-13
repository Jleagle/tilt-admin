// Sources/TiltAdminLib/Models/TiltResource.swift
import Foundation

public struct UIResourceList: Codable, Sendable {
    public let items: [UIResource]
}

public struct UIResource: Codable, Sendable {
    public let metadata: UIResourceMetadata
    public let status: UIResourceStatus?
}

public struct UIResourceMetadata: Codable, Sendable {
    public let name: String
}

public struct UIResourceStatus: Codable, Sendable {
    public let runtimeStatus: String?
    public let updateStatus: String?
    public let disableStatus: DisableStatus?
}

public struct DisableStatus: Codable, Sendable {
    public let state: String?

    public var isDisabled: Bool {
        state == "Disabled"
    }
}

public enum RuntimeStatus: String, Sendable {
    case ok = "ok"
    case pending = "pending"
    case error = "error"
    case notApplicable = "not_applicable"
    case unknown = "unknown"

    public init(from raw: String?) {
        switch raw?.lowercased() {
        case "ok": self = .ok
        case "pending": self = .pending
        case "error": self = .error
        case "not_applicable": self = .notApplicable
        default: self = .unknown
        }
    }
}

public enum UpdateStatus: String, Sendable {
    case ok = "ok"
    case pending = "pending"
    case inProgress = "in_progress"
    case error = "error"
    case notApplicable = "not_applicable"
    case unknown = "unknown"

    public init(from raw: String?) {
        switch raw?.lowercased() {
        case "ok": self = .ok
        case "pending": self = .pending
        case "in_progress": self = .inProgress
        case "error": self = .error
        case "not_applicable": self = .notApplicable
        default: self = .unknown
        }
    }
}
