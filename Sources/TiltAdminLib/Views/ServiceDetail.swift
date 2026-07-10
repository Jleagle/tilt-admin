// Sources/TiltAdminLib/Views/ServiceDetail.swift
import SwiftUI

public struct ServiceDetail: View {
    let serviceName: String
    @Binding var selectedService: String?
    @Environment(TiltManager.self) private var manager

    public init(serviceName: String, selectedService: Binding<String?>) {
        self.serviceName = serviceName
        self._selectedService = selectedService
    }

    private var service: MergedService? {
        manager.services.first(where: { $0.name == serviceName })
    }

    public var body: some View {
        if let service {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(service)
                    toggleSection(service)
                    if !service.directDeps.isEmpty {
                        dependenciesSection(service)
                    }
                    if !service.dependedOnBy.isEmpty {
                        dependentsSection(service)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Service Not Found", systemImage: "questionmark.circle")
        }
    }

    @ViewBuilder
    private func header(_ service: MergedService) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(manager.aggregateColor(for: service))
                .frame(width: 12, height: 12)
            Text(service.name)
                .font(.title)
                .fontWeight(.semibold)
        }

        HStack(spacing: 16) {
            let state = manager.entityState(service.name)
            Label(
                state == .on ? "Enabled" : state == .partial ? "Partially enabled" : "Disabled",
                systemImage: state == .on ? "checkmark.circle.fill"
                    : state == .partial ? "circle.bottomhalf.filled" : "xmark.circle"
            )
            if service.existsInTilt {
                Label("Runtime: \(service.runtimeStatus.rawValue)", systemImage: "server.rack")
                Label("Update: \(service.updateStatus.rawValue)", systemImage: "arrow.clockwise")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func toggleSection(_ service: MergedService) -> some View {
        let state = manager.entityState(service.name)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if state != .on && !manager.enableIsNoOp(service.name) {
                    Button("Enable") {
                        Task { await manager.enableService(service.name) }
                    }
                    .tint(.green)
                }
                if state != .off {
                    Button("Disable") {
                        Task { await manager.disableService(service.name) }
                    }
                    .tint(.red)
                    .disabled(manager.disableIsNoOp(service.name))
                }
            }

            if state != .on {
                let alsoEnable = manager.pendingEnables(for: service.name)
                if !alsoEnable.isEmpty {
                    Text("Will also enable: \(alsoEnable.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if state != .off {
                let alsoDisable = manager.pendingDisables(for: service.name)
                if !alsoDisable.isEmpty {
                    Text("Will also disable: \(alsoDisable.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if state != .off && manager.disableIsNoOp(service.name) {
                Text("Everything this needs is still used by other enabled services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(manager.isOperationInFlight)
    }

    @ViewBuilder
    private func dependenciesSection(_ service: MergedService) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dependencies")
                .font(.headline)
            ForEach(service.directDeps.sorted(), id: \.self) { dep in
                depLink(dep)
            }
        }
    }

    @ViewBuilder
    private func dependentsSection(_ service: MergedService) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Depended On By")
                .font(.headline)
            ForEach(service.dependedOnBy.sorted(), id: \.self) { dep in
                depLink(dep)
            }
        }
    }

    @ViewBuilder
    private func depLink(_ name: String) -> some View {
        if let dep = manager.services.first(where: { $0.name == name }) {
            Button {
                selectedService = name
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(manager.aggregateColor(for: dep))
                        .frame(width: 6, height: 6)
                    Text(name)
                        .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
        } else {
            Text(name)
                .foregroundStyle(.secondary)
        }
    }
}
