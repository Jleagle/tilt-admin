// Sources/TiltAdminLib/Services/DependencyResolver.swift
import Foundation

public enum EntityState: Sendable, Equatable {
    case on
    case partial
    case off
}

/// Pure dependency-state math over a snapshot of config + live Tilt state.
/// No Tilt calls, no MainActor — fully unit-testable.
public struct DependencyResolver: Sendable {
    public let graph: DependencyGraph
    public let topLevel: Set<String>
    public let existsInTilt: Set<String>
    public let enabled: Set<String>

    public init(
        graph: DependencyGraph,
        topLevel: Set<String>,
        existsInTilt: Set<String>,
        enabled: Set<String>
    ) {
        self.graph = graph
        self.topLevel = topLevel
        self.existsInTilt = existsInTilt
        self.enabled = enabled
    }

    /// The Tilt resources that constitute an entity: itself plus all
    /// transitive deps, filtered to what actually exists in Tilt.
    public func resolvedSet(_ name: String) -> Set<String> {
        graph.allTransitiveDeps(for: name)
            .union([name])
            .intersection(existsInTilt)
    }

    /// Tri-state: .on = every member enabled, .off = none (or nothing real),
    /// .partial = somewhere in between.
    public func state(_ name: String) -> EntityState {
        let members = resolvedSet(name)
        guard !members.isEmpty else { return .off }
        let onCount = members.intersection(enabled).count
        if onCount == members.count { return .on }
        if onCount == 0 { return .off }
        return .partial
    }

    /// Everything the entity needs that is currently disabled.
    public func enableSet(_ name: String) -> Set<String> {
        resolvedSet(name).subtracting(enabled)
    }

    /// Everything the entity exclusively needs, minus anything a fully-on
    /// top-level entity (other than the target) still uses. The explicitly
    /// targeted entity is always included — explicit action wins.
    public func disableSet(_ name: String) -> Set<String> {
        let candidates = resolvedSet(name)
        let anchors = topLevel.filter { $0 != name && state($0) == .on }
        var protected = Set<String>()
        for anchor in anchors {
            protected.formUnion(resolvedSet(anchor))
        }
        var result = candidates.subtracting(protected).intersection(enabled)
        if existsInTilt.contains(name) && enabled.contains(name) {
            result.insert(name)
        }
        return result
    }
}
