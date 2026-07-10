// Sources/TiltAdminLib/Views/MenuBarPopover.swift
import SwiftUI

public struct MenuBarPopover: View {
    @Environment(TiltManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(manager.topLevelServices, id: \.id) { service in
                menuBarServiceRow(service)
                Divider()
            }

            HStack {
                Text("\(manager.enabledCount)/\(manager.totalCount) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            Button {
                openWindow(id: "main")
                NSApplication.shared.activate()
            } label: {
                Label("Open Tilt Admin", systemImage: "macwindow")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .onAppear {
            manager.initialize()
            manager.viewAppeared()
        }
        .onDisappear { manager.viewDisappeared() }
    }

    @ViewBuilder
    private func menuBarServiceRow(_ service: MergedService) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(manager.aggregateColor(for: service))
                .frame(width: 8, height: 8)

            Text(service.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: Binding(
                get: { manager.entityState(service.name) == .on },
                set: { newValue in
                    Task {
                        if newValue {
                            await manager.enableService(service.name)
                        } else {
                            await manager.disableService(service.name)
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(manager.isOperationInFlight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
