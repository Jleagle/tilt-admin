// Sources/TiltAdminLib/State/TiltManager.swift
import Foundation
import SwiftUI

@Observable
@MainActor
public final class TiltManager {
    public var services: [MergedService] = []
    public var isLoading = false
    public var error: String?
    public var warnings: [String] = []
    public var tiltAvailable = true
    public var isOperationInFlight = false

    private var config: Config?
    private var graph: DependencyGraph?
    private let tiltClient = TiltClient()
    private var pollingTask: Task<Void, Never>?
    private var visibilityCount = 0

    private var initialized = false

    public init() {}

    // MARK: - Lifecycle

    public func initialize() {
        guard !initialized else { return }
        initialized = true
        loadConfig()
        Task { await checkTilt() }
    }

    // MARK: - Visibility

    public func viewAppeared() {
        visibilityCount += 1
        if visibilityCount == 1 {
            startPolling()
        }
    }

    public func viewDisappeared() {
        visibilityCount = max(0, visibilityCount - 1)
        if visibilityCount == 0 {
            stopPolling()
        }
    }

    // MARK: - Config

    private func loadConfig() {
        do {
            let cfg = try ConfigLoader.load()
            self.config = cfg
            let g = DependencyGraph(config: cfg)
            self.graph = g
            let cycles = g.detectCycles()
            if !cycles.isEmpty {
                warnings = cycles.map { cycle in
                    "Dependency cycle: \(cycle.joined(separator: " -> "))"
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Tilt Check

    private func checkTilt() async {
        do {
            try await tiltClient.checkInstalled()
            tiltAvailable = true
        } catch {
            tiltAvailable = false
            self.error = TiltError.notInstalled.localizedDescription
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
        guard tiltAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resources = try await tiltClient.fetchResources()
            mergeServices(resources: resources)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Merge

    private func mergeServices(resources: [UIResource]) {
        let configServices = config?.services ?? [:]
        let graph = self.graph ?? DependencyGraph(dependencies: [:])
        var merged: [String: MergedService] = [:]

        // Start with all configured services
        for (name, entry) in configServices {
            merged[name] = MergedService(
                name: name,
                isTopLevel: entry.topLevel,
                isConfigured: true,
                directDeps: graph.directDeps(for: name),
                allTransitiveDeps: graph.allTransitiveDeps(for: name),
                dependedOnBy: graph.reverseDeps(for: name)
            )
        }

        // Overlay Tilt runtime data
        for resource in resources {
            let name = resource.metadata.name
            let isDisabled = resource.status?.disableStatus?.isDisabled ?? false

            if var existing = merged[name] {
                existing.isEnabled = !isDisabled
                existing.runtimeStatus = RuntimeStatus(from: resource.status?.runtimeStatus)
                existing.updateStatus = UpdateStatus(from: resource.status?.updateStatus)
                existing.existsInTilt = true
                merged[name] = existing
            } else {
                merged[name] = MergedService(
                    name: name,
                    isEnabled: !isDisabled,
                    runtimeStatus: RuntimeStatus(from: resource.status?.runtimeStatus),
                    updateStatus: UpdateStatus(from: resource.status?.updateStatus),
                    isConfigured: false,
                    existsInTilt: true
                )
            }
        }

        services = merged.values.sorted { $0.name < $1.name }
    }

    // MARK: - Enable / Disable

    public func enableService(_ name: String) async {
        guard !isOperationInFlight, let graph else { return }
        isOperationInFlight = true
        defer { isOperationInFlight = false }

        let deps = graph.allTransitiveDeps(for: name)
        let disabledDeps = deps.filter { dep in
            services.first(where: { $0.name == dep })?.isEnabled == false
        }
        let toEnable = ([name] + disabledDeps.sorted()).filter { svcName in
            services.first(where: { $0.name == svcName })?.existsInTilt == true
        }

        do {
            if !toEnable.isEmpty {
                try await tiltClient.enableServices(toEnable)
            }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func disableService(_ name: String) async {
        guard !isOperationInFlight else { return }
        isOperationInFlight = true
        defer { isOperationInFlight = false }

        let existsInTilt = services.first(where: { $0.name == name })?.existsInTilt == true

        do {
            if existsInTilt {
                try await tiltClient.disableServices([name])
            }
            // Also disable children that exist in Tilt
            if let graph {
                let deps = graph.allTransitiveDeps(for: name)
                let tiltDeps = deps.filter { dep in
                    services.first(where: { $0.name == dep })?.existsInTilt == true
                }.sorted()
                if !tiltDeps.isEmpty {
                    try await tiltClient.disableServices(tiltDeps)
                }
            }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Computed

    public var topLevelServices: [MergedService] {
        services.filter { $0.isTopLevel }
    }

    public var otherServices: [MergedService] {
        let allTopLevelDeps = Set(topLevelServices.flatMap { $0.allTransitiveDeps })
        let topLevelNames = Set(topLevelServices.map { $0.name })
        return services.filter { svc in
            svc.existsInTilt
            && !topLevelNames.contains(svc.name)
            && !allTopLevelDeps.contains(svc.name)
        }
    }

    /// For YAML-only services, derive enabled state from whether any resolved Tilt children are enabled
    public func isEffectivelyEnabled(_ service: MergedService) -> Bool {
        if service.existsInTilt { return service.isEnabled }
        return resolvedTiltChildren(for: service, seen: []).contains { $0.isEnabled }
    }

    private func resolvedTiltChildren(for service: MergedService, seen: Set<String>) -> [MergedService] {
        var result: [MergedService] = []
        for dep in service.directDeps {
            guard !seen.contains(dep) else { continue }
            guard let svc = services.first(where: { $0.name == dep }) else { continue }
            if svc.existsInTilt {
                result.append(svc)
            } else {
                result.append(contentsOf: resolvedTiltChildren(for: svc, seen: seen.union([dep])))
            }
        }
        return result
    }

    public var enabledCount: Int { services.filter(\.isEnabled).count }
    public var totalCount: Int { services.count }
}
