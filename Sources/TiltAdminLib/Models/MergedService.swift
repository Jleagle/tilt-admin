// Sources/TiltAdminLib/Models/MergedService.swift
import Foundation

public struct MergedService: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var isEnabled: Bool
    public var runtimeStatus: RuntimeStatus
    public var updateStatus: UpdateStatus
    public var isTopLevel: Bool
    public var isConfigured: Bool
    public var existsInTilt: Bool
    public var directDeps: Set<String>
    public var allTransitiveDeps: Set<String>
    public var dependedOnBy: Set<String>

    public init(
        name: String,
        isEnabled: Bool = false,
        runtimeStatus: RuntimeStatus = .unknown,
        updateStatus: UpdateStatus = .unknown,
        isTopLevel: Bool = false,
        isConfigured: Bool = false,
        existsInTilt: Bool = false,
        directDeps: Set<String> = [],
        allTransitiveDeps: Set<String> = [],
        dependedOnBy: Set<String> = []
    ) {
        self.id = name
        self.name = name
        self.isEnabled = isEnabled
        self.runtimeStatus = runtimeStatus
        self.updateStatus = updateStatus
        self.isTopLevel = isTopLevel
        self.isConfigured = isConfigured
        self.existsInTilt = existsInTilt
        self.directDeps = directDeps
        self.allTransitiveDeps = allTransitiveDeps
        self.dependedOnBy = dependedOnBy
    }
}
