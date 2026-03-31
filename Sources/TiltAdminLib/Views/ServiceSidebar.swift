// Sources/TiltAdminLib/Views/ServiceSidebar.swift
import SwiftUI

public struct ServiceSidebar: View {
    @Environment(TiltManager.self) private var manager
    @Binding var selectedService: String?
    @State private var searchText = ""

    public init(selectedService: Binding<String?>) {
        self._selectedService = selectedService
    }

    public var body: some View {
        List(selection: $selectedService) {
            Section("Services") {
                ForEach(filteredTopLevel, id: \.id) { service in
                    serviceNode(service, depth: 0)
                }
            }

            if !filteredOther.isEmpty {
                Section("Other") {
                    ForEach(filteredOther, id: \.id) { service in
                        ServiceRow(service: service, statusColor: aggregateColor(for: service))
                            .tag(service.name)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filter services")
    }

    @ViewBuilder
    private func serviceNode(_ service: MergedService, depth: Int) -> some View {
        let children = childServices(for: service)
        if children.isEmpty {
            ServiceRow(service: service, statusColor: aggregateColor(for: service))
                .tag(service.name)
        } else {
            DisclosureGroup {
                ForEach(children, id: \.id) { child in
                    AnyView(serviceNode(child, depth: depth + 1))
                }
            } label: {
                ServiceRow(service: service, statusColor: aggregateColor(for: service))
                    .tag(service.name)
            }
        }
    }

    private func childServices(for service: MergedService) -> [MergedService] {
        resolveChildren(for: service, seen: [])
            .sorted { $0.name < $1.name }
    }

    /// Resolve through YAML-only services (not in Tilt): skip them but include their children
    private func resolveChildren(for service: MergedService, seen: Set<String>) -> [MergedService] {
        var result: [MergedService] = []
        for dep in service.directDeps {
            guard !seen.contains(dep) else { continue }
            guard let svc = manager.services.first(where: { $0.name == dep }) else { continue }
            if svc.existsInTilt {
                result.append(svc)
            } else {
                result.append(contentsOf: resolveChildren(for: svc, seen: seen.union([dep])))
            }
        }
        return result
    }

    // MARK: - Aggregate Status Color

    private func ownColor(for service: MergedService) -> Color {
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

    private func aggregateColor(for service: MergedService) -> Color {
        let children = childServices(for: service)

        // YAML-only services (not in Tilt) derive color purely from children
        if !service.existsInTilt {
            guard !children.isEmpty else { return .gray }
            let childColors = children.map { aggregateColor(for: $0) }
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

        let childColors = children.map { aggregateColor(for: $0) }
        let allColors = [own] + childColors

        let allGreen = allColors.allSatisfy { $0 == .green }
        let someGreen = allColors.contains { $0 == .green }
        let hasError = allColors.contains { $0 == .red }

        if allGreen { return .green }
        if hasError { return .red }
        if someGreen { return .orange }
        return own
    }

    // MARK: - Filtering

    private var filteredTopLevel: [MergedService] {
        let topLevel = manager.topLevelServices
        if searchText.isEmpty { return topLevel }
        return topLevel.filter { matches($0) }
    }

    private var filteredOther: [MergedService] {
        let other = manager.otherServices
        if searchText.isEmpty { return other }
        return other.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func matches(_ service: MergedService) -> Bool {
        if service.name.localizedCaseInsensitiveContains(searchText) { return true }
        return service.allTransitiveDeps.contains { dep in
            dep.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct ServiceRow: View {
    let service: MergedService
    let statusColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(service.name)
                .font(.body)
        }
    }
}
