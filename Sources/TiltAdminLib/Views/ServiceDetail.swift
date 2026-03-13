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
                .fill(statusColor(for: service))
                .frame(width: 12, height: 12)
            Text(service.name)
                .font(.title)
                .fontWeight(.semibold)
        }

        HStack(spacing: 16) {
            Label(service.isEnabled ? "Enabled" : "Disabled",
                  systemImage: service.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
            Label("Runtime: \(service.runtimeStatus.rawValue)", systemImage: "server.rack")
            Label("Update: \(service.updateStatus.rawValue)", systemImage: "arrow.clockwise")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func toggleSection(_ service: MergedService) -> some View {
        HStack {
            if service.isEnabled {
                Button("Disable") {
                    Task { await manager.disableService(service.name) }
                }
                .tint(.red)
            } else {
                Button("Enable") {
                    Task { await manager.enableService(service.name) }
                }
                .tint(.green)

                if !service.allTransitiveDeps.isEmpty {
                    let disabledDeps = service.allTransitiveDeps.filter { dep in
                        manager.services.first(where: { $0.name == dep })?.isEnabled == false
                    }
                    if !disabledDeps.isEmpty {
                        Text("Will also enable: \(disabledDeps.sorted().joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                        .fill(statusColor(for: dep))
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

    private func statusColor(for service: MergedService) -> Color {
        guard service.isEnabled else { return .gray }
        switch service.runtimeStatus {
        case .ok: return .green
        case .pending: return .yellow
        case .error: return .red
        case .notApplicable, .unknown: return .gray
        }
    }
}
