# Tilt Admin Swift Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app that manages Tilt services via a main window and menu bar popover, with YAML-configured dependency resolution.

**Architecture:** Pure SwiftUI app with `@Observable` state management, an actor-based Tilt CLI client, and a dependency graph engine. `MenuBarExtra` for menu bar presence, `NavigationSplitView` for the main window.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 14+, Yams (YAML parsing), Swift concurrency (async/await, actors)

---

## File Structure

```
tilt-admin/
├── Package.swift                              # SPM manifest with Yams dependency
├── Sources/
│   ├── TiltAdmin/
│   │   └── TiltAdminApp.swift                 # @main App entry point (thin wrapper)
│   └── TiltAdminLib/
│       ├── Models/
│       │   ├── ServiceConfig.swift            # YAML config Codable types
│       │   ├── TiltResource.swift             # Tilt CLI JSON response types
│       │   └── MergedService.swift            # Combined config + runtime view model
│       ├── Services/
│       │   ├── TiltClient.swift               # Actor wrapping tilt CLI subprocess calls
│       │   ├── ConfigLoader.swift             # YAML discovery + parsing
│       │   └── DependencyGraph.swift          # Graph algorithms (transitive deps, cycles)
│       ├── State/
│       │   └── TiltManager.swift              # @Observable app state, polling, enable/disable
│       └── Views/
│           ├── MainWindow.swift               # NavigationSplitView shell
│           ├── ServiceSidebar.swift           # Sidebar tree with search
│           ├── ServiceDetail.swift            # Detail pane for selected service
│           └── MenuBarPopover.swift           # Menu bar popover content
├── Tests/
│   └── TiltAdminTests/
│       ├── DependencyGraphTests.swift         # Graph algorithm tests
│       └── ConfigLoaderTests.swift            # YAML parsing tests
└── dependencies.yml                           # Sample config file
```

---

## Chunk 1: Project Scaffold + Models + DependencyGraph

### Task 1: Create Swift Package and Sample Config

**Files:**
- Create: `Package.swift`
- Create: `Sources/TiltAdmin/TiltAdminApp.swift`
- Create: `dependencies.yml`

- [ ] **Step 1: Create Package.swift**

Note: We use a library target for all logic and a thin executable target for the `@main` entry point. This allows `@testable import TiltAdminLibLib` in tests.

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TiltAdmin",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "TiltAdminLib",
            dependencies: ["Yams"],
            path: "Sources/TiltAdminLib"
        ),
        .executableTarget(
            name: "TiltAdmin",
            dependencies: ["TiltAdminLib"],
            path: "Sources/TiltAdmin"
        ),
        .testTarget(
            name: "TiltAdminTests",
            dependencies: ["TiltAdminLib"],
            path: "Tests/TiltAdminTests"
        ),
    ]
)
```

- [ ] **Step 2: Create minimal app entry point**

```swift
// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

@main
struct TiltAdminApp: App {
    var body: some Scene {
        Window("Tilt Admin", id: "main") {
            Text("Tilt Admin")
        }
    }
}
```

- [ ] **Step 3: Create sample dependencies.yml**

```yaml
services:
  traefik:
    depends_on: []
    top_level: true
  chargehive-namespace:
    depends_on: [traefik]
  chargehive-db:
    depends_on: [chargehive-namespace]
  chargehive-assemble:
    depends_on: [chargehive-namespace, chargehive-db]
    top_level: true
  chargehive-api:
    depends_on: [chargehive-assemble]
  connector-stripe:
    depends_on: [chargehive-assemble]
    top_level: true
```

- [ ] **Step 4: Verify project builds**

Run: `cd /Users/jameseagle/code/jleagle/tilt-admin && swift build`
Expected: Build succeeds, binary produced

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/TiltAdmin/TiltAdminApp.swift dependencies.yml
git commit -m "feat: scaffold Swift package with minimal app entry point"
```

---

### Task 2: ServiceConfig Model + ConfigLoader

**Files:**
- Create: `Sources/TiltAdminLib/Models/ServiceConfig.swift`
- Create: `Sources/TiltAdminLib/Services/ConfigLoader.swift`
- Create: `Tests/TiltAdminTests/ConfigLoaderTests.swift`

- [ ] **Step 1: Write ConfigLoader tests**

```swift
// Tests/TiltAdminTests/ConfigLoaderTests.swift
import Testing
import Foundation
@testable import TiltAdminLib

@Suite("ConfigLoader Tests")
struct ConfigLoaderTests {

    @Test("Parses valid YAML with top_level and depends_on")
    func parseValidYAML() throws {
        let yaml = """
        services:
          traefik:
            depends_on: []
            top_level: true
          app:
            depends_on: [traefik]
          db:
            depends_on: [traefik]
            top_level: true
        """
        let config = try ConfigLoader.parse(yaml: yaml)
        #expect(config.services.count == 3)
        #expect(config.services["traefik"]?.topLevel == true)
        #expect(config.services["traefik"]?.dependsOn == [])
        #expect(config.services["app"]?.topLevel == false)
        #expect(config.services["app"]?.dependsOn == ["traefik"])
        #expect(config.services["db"]?.topLevel == true)
    }

    @Test("Parses service with no depends_on defaults to empty")
    func parseServiceNoDepends() throws {
        let yaml = """
        services:
          solo:
            top_level: true
        """
        let config = try ConfigLoader.parse(yaml: yaml)
        #expect(config.services["solo"]?.dependsOn == [])
        #expect(config.services["solo"]?.topLevel == true)
    }

    @Test("Parses service with no top_level defaults to false")
    func parseServiceNoTopLevel() throws {
        let yaml = """
        services:
          child:
            depends_on: [parent]
        """
        let config = try ConfigLoader.parse(yaml: yaml)
        #expect(config.services["child"]?.topLevel == false)
    }

    @Test("Throws on empty YAML")
    func parseEmptyYAML() throws {
        let yaml = ""
        #expect(throws: ConfigError.self) {
            try ConfigLoader.parse(yaml: yaml)
        }
    }

    @Test("Throws on YAML with no services key")
    func parseMissingServicesKey() throws {
        let yaml = "other_key: value"
        #expect(throws: ConfigError.self) {
            try ConfigLoader.parse(yaml: yaml)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ConfigLoaderTests 2>&1 | head -30`
Expected: Compilation errors — `ConfigLoader`, `ConfigError`, `ServiceConfig` not defined

- [ ] **Step 3: Create ServiceConfig model**

```swift
// Sources/TiltAdminLib/Models/ServiceConfig.swift
import Foundation

public struct ServiceConfigEntry: Codable {
    var dependsOn: [String]
    var topLevel: Bool

    enum CodingKeys: String, CodingKey {
        case dependsOn = "depends_on"
        case topLevel = "top_level"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        self.topLevel = try container.decodeIfPresent(Bool.self, forKey: .topLevel) ?? false
    }

    init(dependsOn: [String] = [], topLevel: Bool = false) {
        self.dependsOn = dependsOn
        self.topLevel = topLevel
    }
}

public struct Config: Codable {
    public var services: [String: ServiceConfigEntry]
}
```

- [ ] **Step 4: Create ConfigLoader**

```swift
// Sources/TiltAdminLib/Services/ConfigLoader.swift
import Foundation
import Yams

public enum ConfigError: Error, LocalizedError {
    case fileNotFound
    case parseError(String)
    case emptyConfig

    var errorDescription: String? {
        switch self {
        case .fileNotFound: "Configuration file not found"
        case .parseError(let msg): "Failed to parse config: \(msg)"
        case .emptyConfig: "Configuration is empty or missing 'services' key"
        }
    }
}

public struct ConfigLoader {

    public static func parse(yaml: String) throws -> Config {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigError.emptyConfig
        }
        do {
            let config = try YAMLDecoder().decode(Config.self, from: yaml)
            return config
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }

    static func load() throws -> Config {
        let path = try discoverConfigPath()
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: yaml)
    }

    static func discoverConfigPath() throws -> String {
        let fm = FileManager.default
        let candidates = [
            fm.currentDirectoryPath + "/dependencies.yml",
            fm.currentDirectoryPath + "/dependencies.yaml",
            NSHomeDirectory() + "/.config/tilt-admin/config.yaml",
        ]
        for path in candidates {
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        throw ConfigError.fileNotFound
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ConfigLoaderTests 2>&1`
Expected: All 5 tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/TiltAdminLib/Models/ServiceConfig.swift Sources/TiltAdminLib/Services/ConfigLoader.swift Tests/TiltAdminTests/ConfigLoaderTests.swift
git commit -m "feat: add ServiceConfig model and ConfigLoader with YAML parsing"
```

---

### Task 3: DependencyGraph

**Files:**
- Create: `Sources/TiltAdminLib/Services/DependencyGraph.swift`
- Create: `Tests/TiltAdminTests/DependencyGraphTests.swift`

- [ ] **Step 1: Write DependencyGraph tests**

```swift
// Tests/TiltAdminTests/DependencyGraphTests.swift
import Testing
@testable import TiltAdminLib

@Suite("DependencyGraph Tests")
struct DependencyGraphTests {

    func makeGraph(_ deps: [String: [String]]) -> DependencyGraph {
        DependencyGraph(dependencies: deps)
    }

    // -- Direct deps --

    @Test("Direct deps returns immediate dependencies")
    func directDeps() {
        let graph = makeGraph(["a": ["b", "c"], "b": ["d"], "c": [], "d": []])
        #expect(graph.directDeps(for: "a") == Set(["b", "c"]))
        #expect(graph.directDeps(for: "b") == Set(["d"]))
        #expect(graph.directDeps(for: "c") == Set())
    }

    @Test("Direct deps for unknown service returns empty")
    func directDepsUnknown() {
        let graph = makeGraph(["a": ["b"]])
        #expect(graph.directDeps(for: "z") == Set())
    }

    // -- Transitive deps --

    @Test("Transitive deps resolves full chain")
    func transitiveDeps() {
        let graph = makeGraph(["a": ["b"], "b": ["c"], "c": ["d"], "d": []])
        #expect(graph.allTransitiveDeps(for: "a") == Set(["b", "c", "d"]))
    }

    @Test("Transitive deps handles diamond pattern")
    func transitiveDiamond() {
        let graph = makeGraph(["a": ["b", "c"], "b": ["d"], "c": ["d"], "d": []])
        #expect(graph.allTransitiveDeps(for: "a") == Set(["b", "c", "d"]))
    }

    @Test("Transitive deps stops at cycle")
    func transitiveCycle() {
        let graph = makeGraph(["a": ["b"], "b": ["c"], "c": ["a"]])
        let deps = graph.allTransitiveDeps(for: "a")
        #expect(deps == Set(["b", "c"]))
    }

    // -- Reverse deps --

    @Test("Reverse deps finds dependents")
    func reverseDeps() {
        let graph = makeGraph(["a": ["c"], "b": ["c"], "c": []])
        #expect(graph.reverseDeps(for: "c") == Set(["a", "b"]))
        #expect(graph.reverseDeps(for: "a") == Set())
    }

    // -- Cycle detection --

    @Test("No cycles detected in acyclic graph")
    func noCycles() {
        let graph = makeGraph(["a": ["b"], "b": ["c"], "c": []])
        #expect(graph.detectCycles().isEmpty)
    }

    @Test("Cycle detected in cyclic graph")
    func hasCycle() {
        let graph = makeGraph(["a": ["b"], "b": ["c"], "c": ["a"]])
        let cycles = graph.detectCycles()
        #expect(!cycles.isEmpty)
    }

    @Test("Self-referencing service detected as cycle")
    func selfCycle() {
        let graph = makeGraph(["a": ["a"]])
        let cycles = graph.detectCycles()
        #expect(!cycles.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DependencyGraphTests 2>&1 | head -20`
Expected: Compilation error — `DependencyGraph` not defined

- [ ] **Step 3: Implement DependencyGraph**

```swift
// Sources/TiltAdminLib/Services/DependencyGraph.swift
import Foundation

public struct DependencyGraph: Sendable {
    let dependencies: [String: [String]]

    init(dependencies: [String: [String]]) {
        self.dependencies = dependencies
    }

    init(config: Config) {
        self.dependencies = config.services.mapValues { $0.dependsOn }
    }

    func directDeps(for service: String) -> Set<String> {
        Set(dependencies[service] ?? [])
    }

    func allTransitiveDeps(for service: String) -> Set<String> {
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

    func reverseDeps(for service: String) -> Set<String> {
        var result = Set<String>()
        for (name, deps) in dependencies {
            if deps.contains(service) {
                result.insert(name)
            }
        }
        return result
    }

    func detectCycles() -> [[String]] {
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DependencyGraphTests 2>&1`
Expected: All 9 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/TiltAdminLib/Services/DependencyGraph.swift Tests/TiltAdminTests/DependencyGraphTests.swift
git commit -m "feat: add DependencyGraph with transitive resolution and cycle detection"
```

---

### Task 4: TiltResource Model

**Files:**
- Create: `Sources/TiltAdminLib/Models/TiltResource.swift`

- [ ] **Step 1: Create TiltResource model**

The `tilt get uiresource -o json` command returns a K8s-style List. We need to parse `items`, extracting `metadata.name`, `status.runtimeStatus`, `status.updateStatus`, and `status.disableStatus.disabled`.

```swift
// Sources/TiltAdminLib/Models/TiltResource.swift
import Foundation

struct UIResourceList: Codable {
    let items: [UIResource]
}

struct UIResource: Codable {
    let metadata: UIResourceMetadata
    let status: UIResourceStatus?
}

struct UIResourceMetadata: Codable {
    let name: String
}

struct UIResourceStatus: Codable {
    let runtimeStatus: String?
    let updateStatus: String?
    let disableStatus: DisableStatus?
}

struct DisableStatus: Codable {
    let disabled: Bool?
}

public enum RuntimeStatus: String, Sendable {
    case ok = "ok"
    case pending = "pending"
    case error = "error"
    case notApplicable = "not_applicable"
    case unknown = "unknown"

    init(from raw: String?) {
        switch raw?.lowercased() {
        case "ok": self = .ok
        case "pending": self = .pending
        case "error": self = .error
        case "not_applicable": self = .notApplicable
        default: self = .unknown
        }
    }
}

public enum UpdateStatus: String, Sendable {
    case ok = "ok"
    case pending = "pending"
    case inProgress = "in_progress"
    case error = "error"
    case notApplicable = "not_applicable"
    case unknown = "unknown"

    init(from raw: String?) {
        switch raw?.lowercased() {
        case "ok": self = .ok
        case "pending": self = .pending
        case "in_progress": self = .inProgress
        case "error": self = .error
        case "not_applicable": self = .notApplicable
        default: self = .unknown
        }
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/Models/TiltResource.swift
git commit -m "feat: add TiltResource model for parsing Tilt CLI JSON output"
```

---

### Task 5: MergedService Model

**Files:**
- Create: `Sources/TiltAdminLib/Models/MergedService.swift`

- [ ] **Step 1: Create MergedService**

```swift
// Sources/TiltAdminLib/Models/MergedService.swift
import Foundation

public struct MergedService: Identifiable, Sendable {
    public let id: String // service name
    public let name: String
    public var isEnabled: Bool
    public var runtimeStatus: RuntimeStatus
    public var updateStatus: UpdateStatus
    public var isTopLevel: Bool
    public var isConfigured: Bool // false if only in Tilt, not in YAML
    public var directDeps: Set<String>
    public var allTransitiveDeps: Set<String>
    public var dependedOnBy: Set<String>

    init(
        name: String,
        isEnabled: Bool = false,
        runtimeStatus: RuntimeStatus = .unknown,
        updateStatus: UpdateStatus = .unknown,
        isTopLevel: Bool = false,
        isConfigured: Bool = false,
        directDeps: Set<String> = [],
        allTransitiveDeps: Set<String> = [],
        dependedOnBy: Set<String> = []
    ) {
        self.id = name
        self.name = name
        self.isEnabled = isEnabled
        self.runtimeStatus = runtimeStatus
        self.updateStatus = updateStatus
        self.isTopLevel = isTopLevel
        self.isConfigured = isConfigured
        self.directDeps = directDeps
        self.allTransitiveDeps = allTransitiveDeps
        self.dependedOnBy = dependedOnBy
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/Models/MergedService.swift
git commit -m "feat: add MergedService view model combining config and runtime data"
```

---

## Chunk 2: TiltClient + TiltManager + Polling

### Task 6: TiltClient Actor

**Files:**
- Create: `Sources/TiltAdminLib/Services/TiltClient.swift`

- [ ] **Step 1: Implement TiltClient**

```swift
// Sources/TiltAdminLib/Services/TiltClient.swift
import Foundation

enum TiltError: Error, LocalizedError {
    case notInstalled
    case commandFailed(String)
    case timeout
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "Tilt CLI not found. Ensure 'tilt' is in your PATH."
        case .commandFailed(let msg): "Tilt command failed: \(msg)"
        case .timeout: "Tilt command timed out (10s)"
        case .parseError(let msg): "Failed to parse Tilt output: \(msg)"
        }
    }
}

actor TiltClient {
    private let timeoutSeconds: Double = 10

    func checkInstalled() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "tilt"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw TiltError.notInstalled
        }
    }

    func fetchResources() async throws -> [UIResource] {
        let output = try await runTilt(arguments: ["get", "uiresource", "-o", "json"])
        guard let data = output.data(using: .utf8) else {
            throw TiltError.parseError("Invalid UTF-8 output")
        }
        do {
            let list = try JSONDecoder().decode(UIResourceList.self, from: data)
            return list.items
        } catch {
            throw TiltError.parseError(error.localizedDescription)
        }
    }

    func enableServices(_ names: [String]) async throws {
        guard !names.isEmpty else { return }
        try await runTilt(arguments: ["enable"] + names)
    }

    func disableServices(_ names: [String]) async throws {
        guard !names.isEmpty else { return }
        try await runTilt(arguments: ["disable"] + names)
    }

    @discardableResult
    private func runTilt(arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tilt"] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Timeout via Task
        let pid = process.processIdentifier
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeoutSeconds))
            kill(pid, SIGTERM)
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            if process.terminationStatus == 15 { // SIGTERM
                throw TiltError.timeout
            }
            throw TiltError.commandFailed(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/Services/TiltClient.swift
git commit -m "feat: add TiltClient actor with CLI subprocess calls and timeout"
```

---

### Task 7: TiltManager State

**Files:**
- Create: `Sources/TiltAdminLib/State/TiltManager.swift`

- [ ] **Step 1: Implement TiltManager**

```swift
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

    public init() {}

    // MARK: - Lifecycle

    public func initialize() {
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

    func refresh() async {
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
            let isDisabled = resource.status?.disableStatus?.disabled ?? false

            if var existing = merged[name] {
                existing.isEnabled = !isDisabled
                existing.runtimeStatus = RuntimeStatus(from: resource.status?.runtimeStatus)
                existing.updateStatus = UpdateStatus(from: resource.status?.updateStatus)
                merged[name] = existing
            } else {
                merged[name] = MergedService(
                    name: name,
                    isEnabled: !isDisabled,
                    runtimeStatus: RuntimeStatus(from: resource.status?.runtimeStatus),
                    updateStatus: UpdateStatus(from: resource.status?.updateStatus),
                    isConfigured: false
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
        let toEnable = [name] + disabledDeps.sorted()

        do {
            try await tiltClient.enableServices(toEnable)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func disableService(_ name: String) async {
        guard !isOperationInFlight else { return }
        isOperationInFlight = true
        defer { isOperationInFlight = false }

        do {
            try await tiltClient.disableServices([name])
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
            !topLevelNames.contains(svc.name) && !allTopLevelDeps.contains(svc.name)
        }
    }

    public var enabledCount: Int { services.filter(\.isEnabled).count }
    public var totalCount: Int { services.count }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/State/TiltManager.swift
git commit -m "feat: add TiltManager with polling, merging, enable/disable logic"
```

---

## Chunk 3: Views — Main Window

### Task 8: ServiceSidebar View

**Files:**
- Create: `Sources/TiltAdminLib/Views/ServiceSidebar.swift`

- [ ] **Step 1: Implement ServiceSidebar**

```swift
// Sources/TiltAdminLib/Views/ServiceSidebar.swift
import SwiftUI

public struct ServiceSidebar: View {
    @Environment(TiltManager.self) private var manager
    @Binding var selectedService: String?
    @State private var searchText = ""

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
                        ServiceRow(service: service)
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
            ServiceRow(service: service)
                .tag(service.name)
        } else {
            DisclosureGroup {
                ForEach(children, id: \.id) { child in
                    serviceNode(child, depth: depth + 1)
                }
            } label: {
                ServiceRow(service: service)
                    .tag(service.name)
            }
        }
    }

    private func childServices(for service: MergedService) -> [MergedService] {
        service.directDeps.compactMap { dep in
            manager.services.first(where: { $0.name == dep })
        }.sorted { $0.name < $1.name }
    }

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

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(service.name)
                .font(.body)
                .foregroundStyle(service.isConfigured ? .primary : .secondary)

            if !service.isConfigured {
                Text("unconfigured")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusColor: Color {
        guard service.isEnabled else { return .gray }
        switch service.runtimeStatus {
        case .ok: .green
        case .pending: .yellow
        case .error: .red
        case .notApplicable, .unknown: .gray
        }
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/Views/ServiceSidebar.swift
git commit -m "feat: add ServiceSidebar with tree hierarchy and search filter"
```

---

### Task 9: ServiceDetail View

**Files:**
- Create: `Sources/TiltAdminLib/Views/ServiceDetail.swift`

- [ ] **Step 1: Implement ServiceDetail**

```swift
// Sources/TiltAdminLib/Views/ServiceDetail.swift
import SwiftUI

struct ServiceDetail: View {
    let serviceName: String
    @Binding var selectedService: String?
    @Environment(TiltManager.self) private var manager

    private var service: MergedService? {
        manager.services.first(where: { $0.name == serviceName })
    }

    var body: some View {
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
        case .ok: .green
        case .pending: .yellow
        case .error: .red
        case .notApplicable, .unknown: .gray
        }
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdminLib/Views/ServiceDetail.swift
git commit -m "feat: add ServiceDetail view with status, toggle, and dependency lists"
```

---

### Task 10: MainWindow View

**Files:**
- Create: `Sources/TiltAdminLib/Views/MainWindow.swift`
- Modify: `Sources/TiltAdmin/TiltAdminApp.swift`

- [ ] **Step 1: Implement MainWindow**

```swift
// Sources/TiltAdminLib/Views/MainWindow.swift
import SwiftUI

public struct MainWindow: View {
    @Environment(TiltManager.self) private var manager
    @State private var selectedService: String?

    var body: some View {
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
```

- [ ] **Step 2: Update TiltAdminApp to use MainWindow**

```swift
// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

@main
struct TiltAdminApp: App {
    @State private var manager = TiltManager()

    var body: some Scene {
        Window("Tilt Admin", id: "main") {
            MainWindow()
                .environment(manager)
                .task { manager.initialize() }
        }
    }
}
```

Note: `initialize()` is called via `.task` modifier which runs on `@MainActor`, avoiding concurrency issues with calling it from `init()`.

- [ ] **Step 3: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/TiltAdminLib/Views/MainWindow.swift Sources/TiltAdmin/TiltAdminApp.swift
git commit -m "feat: add MainWindow with NavigationSplitView and status bar"
```

---

## Chunk 4: Menu Bar + Final Wiring

### Task 11: MenuBarPopover View

**Files:**
- Create: `Sources/TiltAdminLib/Views/MenuBarPopover.swift`
- Modify: `Sources/TiltAdmin/TiltAdminApp.swift`

- [ ] **Step 1: Implement MenuBarPopover**

```swift
// Sources/TiltAdminLib/Views/MenuBarPopover.swift
import SwiftUI

public struct MenuBarPopover: View {
    @Environment(TiltManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
        .onAppear { manager.viewAppeared() }
        .onDisappear { manager.viewDisappeared() }
    }

    @ViewBuilder
    private func menuBarServiceRow(_ service: MergedService) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(for: service))
                .frame(width: 8, height: 8)

            Text(service.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: Binding(
                get: { service.isEnabled },
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

    private func statusColor(for service: MergedService) -> Color {
        guard service.isEnabled else { return .gray }
        switch service.runtimeStatus {
        case .ok: .green
        case .pending: .yellow
        case .error: .red
        case .notApplicable, .unknown: .gray
        }
    }
}
```

- [ ] **Step 2: Update TiltAdminApp with MenuBarExtra**

```swift
// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

@main
struct TiltAdminApp: App {
    @State private var manager = TiltManager()

    var body: some Scene {
        Window("Tilt Admin", id: "main") {
            MainWindow()
                .environment(manager)
                .task { manager.initialize() }
        }

        MenuBarExtra("Tilt Admin", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarPopover()
                .environment(manager)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/TiltAdminLib/Views/MenuBarPopover.swift Sources/TiltAdmin/TiltAdminApp.swift
git commit -m "feat: add MenuBarPopover with top-level service toggles and MenuBarExtra"
```

---

### Task 12: Window Management — Close Without Quit

**Files:**
- Modify: `Sources/TiltAdmin/TiltAdminApp.swift`

The default SwiftUI behavior quits the app when the last window closes. We need to override this so the app keeps running in the menu bar.

- [ ] **Step 1: Add AppDelegate to prevent quit on window close**

Update `Sources/TiltAdmin/TiltAdminApp.swift`:

```swift
// Sources/TiltAdmin/TiltAdminApp.swift
import SwiftUI
import TiltAdminLib

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct TiltAdminApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var manager = TiltManager()

    var body: some Scene {
        Window("Tilt Admin", id: "main") {
            MainWindow()
                .environment(manager)
                .task { manager.initialize() }
        }

        MenuBarExtra("Tilt Admin", systemImage: "arrow.triangle.2.circlepath") {
            MenuBarPopover()
                .environment(manager)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Verify project builds**

Run: `swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/TiltAdmin/TiltAdminApp.swift
git commit -m "feat: keep app running in menu bar when main window is closed"
```

---

### Task 13: Run All Tests and Final Verification

- [ ] **Step 1: Run full test suite**

Run: `swift test 2>&1`
Expected: All tests pass (ConfigLoaderTests + DependencyGraphTests)

- [ ] **Step 2: Build release**

Run: `swift build -c release 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Commit any remaining changes**

```bash
git status
# If clean, no commit needed
```
