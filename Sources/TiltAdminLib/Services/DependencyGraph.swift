// Sources/TiltAdminLib/Services/DependencyGraph.swift
import Foundation

public struct DependencyGraph: Sendable {
    public let dependencies: [String: [String]]

    public init(dependencies: [String: [String]]) {
        self.dependencies = dependencies
    }

    public init(config: Config) {
        self.dependencies = config.services.mapValues { $0.dependsOn }
    }

    public func directDeps(for service: String) -> Set<String> {
        Set(dependencies[service] ?? [])
    }

    public func allTransitiveDeps(for service: String) -> Set<String> {
        var result = Set<String>()
        var queue = Array(directDeps(for: service))
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard result.insert(current).inserted else { continue }
            for dep in dependencies[current] ?? [] {
                if dep != service && !result.contains(dep) {
                    queue.append(dep)
                }
            }
        }
        return result
    }

    public func reverseDeps(for service: String) -> Set<String> {
        var result = Set<String>()
        for (name, deps) in dependencies {
            if deps.contains(service) {
                result.insert(name)
            }
        }
        return result
    }

    public func detectCycles() -> [[String]] {
        var visited = Set<String>()
        var inStack = Set<String>()
        var cycles: [[String]] = []
        var path: [String] = []

        func dfs(_ node: String) {
            guard !visited.contains(node) else { return }
            visited.insert(node)
            inStack.insert(node)
            path.append(node)

            for dep in dependencies[node] ?? [] {
                if inStack.contains(dep) {
                    if let start = path.firstIndex(of: dep) {
                        cycles.append(Array(path[start...]))
                    }
                } else if !visited.contains(dep) {
                    dfs(dep)
                }
            }

            path.removeLast()
            inStack.remove(node)
        }

        for node in dependencies.keys.sorted() {
            dfs(node)
        }
        return cycles
    }
}
