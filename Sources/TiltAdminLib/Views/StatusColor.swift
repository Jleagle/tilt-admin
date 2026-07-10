// Sources/TiltAdminLib/Views/StatusColor.swift
import SwiftUI

extension TiltManager {
    /// Color from a service's own Tilt status only.
    public func ownColor(for service: MergedService) -> Color {
        guard service.isEnabled else { return .gray }
        switch service.runtimeStatus {
        case .ok: return .green
        case .pending: return .yellow
        case .error: return .red
        case .notApplicable:
            // Run-once services (e.g. local_resource builds) have no runtime
            // but updateStatus "ok" means they completed successfully
            return service.updateStatus == .ok ? .green : .gray
        case .unknown: return .gray
        }
    }

    /// Color blending a service's own status with all resolved children.
    public func aggregateColor(for service: MergedService, seen: Set<String> = []) -> Color {
        guard !seen.contains(service.name) else { return .gray }
        let seen = seen.union([service.name])
        let children = tiltChildren(of: service).sorted { $0.name < $1.name }

        // YAML-only services (not in Tilt) derive color purely from children
        if !service.existsInTilt {
            guard !children.isEmpty else { return .gray }
            let childColors = children.map { aggregateColor(for: $0, seen: seen) }
            let allGreen = childColors.allSatisfy { $0 == .green }
            let someGreen = childColors.contains { $0 == .green }
            let hasError = childColors.contains { $0 == .red }
            if allGreen { return .green }
            if hasError { return .red }
            if someGreen { return .orange }
            return .gray
        }

        let own = ownColor(for: service)
        guard service.isEnabled else { return own }
        guard !children.isEmpty else { return own }

        let childColors = children.map { aggregateColor(for: $0, seen: seen) }
        let allColors = [own] + childColors

        let allGreen = allColors.allSatisfy { $0 == .green }
        let someGreen = allColors.contains { $0 == .green }
        let hasError = allColors.contains { $0 == .red }

        if allGreen { return .green }
        if hasError { return .red }
        if someGreen { return .orange }
        return own
    }
}
