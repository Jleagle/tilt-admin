// Sources/TiltAdminLib/Models/TiltResource.swift
import Foundation

public struct UIResourceList: Codable {
    public let items: [UIResource]
}

public struct UIResource: Codable {
    public let metadata: UIResourceMetadata
    public let status: UIResourceStatus?
}

public struct UIResourceMetadata: Codable {
    public let name: String
}

public struct UIResourceStatus: Codable {
    public let runtimeStatus: String?
    public let updateStatus: String?
    public let disableStatus: DisableStatus?
}

public struct DisableStatus: Codable {
    public let disabled: Bool?
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
