// Sources/TiltAdminLib/Models/ServiceConfig.swift
import Foundation

public struct ServiceConfigEntry: Codable {
    public var dependsOn: [String]
    public var topLevel: Bool

    enum CodingKeys: String, CodingKey {
        case dependsOn = "depends_on"
        case topLevel = "top_level"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        self.topLevel = try container.decodeIfPresent(Bool.self, forKey: .topLevel) ?? false
    }

    public init(dependsOn: [String] = [], topLevel: Bool = false) {
        self.dependsOn = dependsOn
        self.topLevel = topLevel
    }
}

public struct Config: Codable {
    public var services: [String: ServiceConfigEntry]
}
