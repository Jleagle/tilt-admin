// Tests/TiltAdminTests/DependencyGraphTests.swift
import Testing
@testable import TiltAdminLib

@Suite("DependencyGraph Tests")
struct DependencyGraphTests {

    func makeGraph(_ deps: [String: [String]]) -> DependencyGraph {
        DependencyGraph(dependencies: deps)
    }

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

    @Test("Reverse deps finds dependents")
    func reverseDeps() {
        let graph = makeGraph(["a": ["c"], "b": ["c"], "c": []])
        #expect(graph.reverseDeps(for: "c") == Set(["a", "b"]))
        #expect(graph.reverseDeps(for: "a") == Set())
    }

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
