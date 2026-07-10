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
        guard !isOperationInFlight else { return }
        isOperationInFlight = true
        defer { isOperationInFlight = false }

        // Must be computed before the first await — snapshot of the state the user acted on.
        let toEnable = makeResolver().enableSet(name).sorted()

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

        // Must be computed before the first await — snapshot of the state the user acted on.
        let toDisable = makeResolver().disableSet(name).sorted()

        do {
            if !toDisable.isEmpty {
                try await tiltClient.disableServices(toDisable)
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

    // MARK: - Resolver

    /// Builds a fresh dependency-state snapshot. Each call sees the current
    /// `services`; never hold one across an await.
    private func makeResolver() -> DependencyResolver {
        DependencyResolver(
            graph: graph ?? DependencyGraph(dependencies: [:]),
            topLevel: Set(services.filter(\.isTopLevel).map(\.name)),
            existsInTilt: Set(services.filter(\.existsInTilt).map(\.name)),
            enabled: Set(services.filter { $0.existsInTilt && $0.isEnabled }.map(\.name))
        )
    }

    public func entityState(_ name: String) -> EntityState {
        makeResolver().state(name)
    }

    /// Resources that would additionally be enabled by enableService(name).
    public func pendingEnables(for name: String) -> [String] {
        makeResolver().enableSet(name).subtracting([name]).sorted()
    }

    /// Resources that would additionally be disabled by disableService(name).
    public func pendingDisables(for name: String) -> [String] {
        makeResolver().disableSet(name).subtracting([name]).sorted()
    }

    /// True when enableService(name) would issue no CLI call.
    public func enableIsNoOp(_ name: String) -> Bool {
        makeResolver().enableSet(name).isEmpty
    }

    /// True when disableService(name) would issue no CLI call
    /// (everything is protected by other fully-on top-level entities).
    public func disableIsNoOp(_ name: String) -> Bool {
        makeResolver().disableSet(name).isEmpty
    }

    /// Direct children of an entity, resolving THROUGH YAML-only entities:
    /// a YAML-only child is replaced by its own resolved children.
    /// Result is deduplicated by name (shared deps appear once).
    /// Order is not guaranteed (directDeps is a Set); callers sort.
    public func tiltChildren(of service: MergedService, seen: Set<String> = []) -> [MergedService] {
        var result: [MergedService] = []
        var names = Set<String>()
        for dep in service.directDeps {
            guard !seen.contains(dep) else { continue }
            guard let svc = services.first(where: { $0.name == dep }) else { continue }
            if svc.existsInTilt {
                if names.insert(svc.name).inserted {
                    result.append(svc)
                }
            } else {
                for child in tiltChildren(of: svc, seen: seen.union([dep])) {
                    if names.insert(child.name).inserted {
                        result.append(child)
                    }
                }
            }
        }
        return result
    }

    public var enabledCount: Int { services.filter(\.isEnabled).count }
    public var totalCount: Int { services.count }
}
