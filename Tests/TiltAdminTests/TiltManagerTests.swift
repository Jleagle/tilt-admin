// Tests/TiltAdminTests/TiltManagerTests.swift
import Testing
@testable import TiltAdminLib

@Suite("TiltManager")
@MainActor
struct TiltManagerTests {

    @Test("tiltChildren resolves through YAML-only entities and dedupes by name")
    func tiltChildrenDedupes() {
        let manager = TiltManager()
        // parent -> [shared (Tilt), group (YAML-only)]; group -> [shared, leaf]
        // "shared" is reachable both directly and through the group: must appear once.
        let shared = MergedService(name: "shared", existsInTilt: true)
        let leaf = MergedService(name: "leaf", existsInTilt: true)
        let group = MergedService(name: "group", isConfigured: true, directDeps: ["shared", "leaf"])
        let parent = MergedService(
            name: "parent",
            isConfigured: true,
            directDeps: ["shared", "group"]
        )
        manager.services = [shared, leaf, group, parent]

        let children = manager.tiltChildren(of: parent)
        #expect(children.map(\.name).sorted() == ["leaf", "shared"])
    }
}
