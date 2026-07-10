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
                        ServiceRow(service: service, statusColor: manager.aggregateColor(for: service))
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
            ServiceRow(service: service, statusColor: manager.aggregateColor(for: service))
                .tag(service.name)
        } else {
            DisclosureGroup {
                ForEach(children, id: \.id) { child in
                    AnyView(serviceNode(child, depth: depth + 1))
                }
            } label: {
                ServiceRow(service: service, statusColor: manager.aggregateColor(for: service))
                    .tag(service.name)
            }
        }
    }

    private func childServices(for service: MergedService) -> [MergedService] {
        manager.tiltChildren(of: service)
            .sorted { $0.name < $1.name }
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
