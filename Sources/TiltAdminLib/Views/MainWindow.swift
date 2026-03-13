// Sources/TiltAdminLib/Views/MainWindow.swift
import SwiftUI

public struct MainWindow: View {
    @Environment(TiltManager.self) private var manager
    @State private var selectedService: String?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            ServiceSidebar(selectedService: $selectedService)
        } detail: {
            if let selectedService {
                ServiceDetail(serviceName: selectedService, selectedService: $selectedService)
            } else {
                ContentUnavailableView(
                    "Select a Service",
                    systemImage: "sidebar.left",
                    description: Text("Choose a service from the sidebar to view its details")
                )
            }
        }
        .navigationTitle("Tilt Admin")
        .overlay(alignment: .bottom) {
            statusBar
        }
        .onAppear { manager.viewAppeared() }
        .onDisappear { manager.viewDisappeared() }
    }

    @ViewBuilder
    private var statusBar: some View {
        HStack {
            if manager.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text("\(manager.enabledCount)/\(manager.totalCount) enabled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let error = manager.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !manager.warnings.isEmpty {
                Label("\(manager.warnings.count) warning(s)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(manager.warnings.joined(separator: "\n"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
