import Testing
@testable import TiltAdminLib

@Suite("DependencyResolver")
struct DependencyResolverTests {

    // Fixture:
    //   topA (top_level, YAML-only)  -> mid-a
    //   topB (top_level, in Tilt)    -> mid-b
    //   mid-a (Tilt) -> shared, a-only, ghost   (ghost = config-only, not in Tilt)
    //   mid-b (Tilt) -> shared, b-only
    //   shared, a-only, b-only (Tilt leaves)
    static let graph = DependencyGraph(dependencies: [
        "topA": ["mid-a"],
        "topB": ["mid-b"],
        "mid-a": ["shared", "a-only", "ghost"],
        "mid-b": ["shared", "b-only"],
    ])
    static let topLevel: Set<String> = ["topA", "topB"]
    static let inTilt: Set<String> = ["topB", "mid-a", "mid-b", "shared", "a-only", "b-only"]
    static let allOn: Set<String> = inTilt

    private func resolver(enabled: Set<String>) -> DependencyResolver {
        DependencyResolver(
            graph: Self.graph,
            topLevel: Self.topLevel,
            existsInTilt: Self.inTilt,
            enabled: enabled
        )
    }

    // MARK: - resolvedSet

    @Test("Resolved set includes self and transitive deps, filtered to Tilt")
    func resolvedSetFiltersToTilt() {
        let r = resolver(enabled: [])
        // topA is YAML-only and ghost is config-only: both excluded
        #expect(r.resolvedSet("topA") == ["mid-a", "shared", "a-only"])
        // topB exists in Tilt: included
        #expect(r.resolvedSet("topB") == ["topB", "mid-b", "shared", "b-only"])
    }

    // MARK: - state

    @Test("State is on when every resolved member is enabled")
    func stateOn() {
        let r = resolver(enabled: Self.allOn)
        #expect(r.state("topA") == .on)
        #expect(r.state("topB") == .on)
    }

    @Test("State is partial when only some members are enabled")
    func statePartial() {
        let r = resolver(enabled: Self.allOn.subtracting(["a-only"]))
        #expect(r.state("topA") == .partial)
        #expect(r.state("topB") == .on)
    }

    @Test("State is off when no member is enabled")
    func stateOff() {
        let r = resolver(enabled: [])
        #expect(r.state("topA") == .off)
        #expect(r.state("topB") == .off)
    }

    @Test("State is off for empty resolved set (config-only entity)")
    func stateEmptySet() {
        let r = resolver(enabled: Self.allOn)
        #expect(r.state("ghost") == .off)
    }

    @Test("Missing-in-Tilt deps are ignored by state")
    func stateIgnoresGhostDeps() {
        // ghost is a dep of mid-a but doesn't exist in Tilt; topA can still be fully on
        let r = resolver(enabled: Self.allOn)
        #expect(r.state("mid-a") == .on)
    }

    // MARK: - enableSet

    @Test("Enable set fills only the gaps, excluding YAML-only names")
    func enableSetGaps() {
        let r = resolver(enabled: ["shared"])
        #expect(r.enableSet("topA") == ["mid-a", "a-only"])
    }

    @Test("Enable set includes manually disabled children")
    func enableSetManuallyDisabled() {
        let r = resolver(enabled: Self.allOn.subtracting(["a-only"]))
        #expect(r.enableSet("topA") == ["a-only"])
    }

    @Test("Enable set is empty when fully on")
    func enableSetEmpty() {
        let r = resolver(enabled: Self.allOn)
        #expect(r.enableSet("topA").isEmpty)
    }

    // MARK: - disableSet

    @Test("Shared dep protected when another top-level is fully on")
    func disableProtectsShared() {
        let r = resolver(enabled: Self.allOn)
        // topB fully on protects {topB, mid-b, shared, b-only}
        #expect(r.disableSet("topA") == ["mid-a", "a-only"])
    }

    @Test("Shared dep not protected when the other top-level is partial")
    func disablePartialDoesNotProtect() {
        let r = resolver(enabled: Self.allOn.subtracting(["b-only"]))
        // topB partial: no anchor; everything of topA's that is on goes down
        #expect(r.disableSet("topA") == ["mid-a", "shared", "a-only"])
    }

    @Test("Explicit target always disabled even when a fully-on top-level needs it")
    func disableExplicitTargetWins() {
        let r = resolver(enabled: Self.allOn)
        // shared is needed by both fully-on top-levels, but the user asked for it
        #expect(r.disableSet("shared") == ["shared"])
    }

    @Test("Non-top-level fully-on entities do not protect")
    func disableNonTopLevelDoesNotProtect() {
        // topB itself is off, so topB is partial; mid-b subtree fully on
        let r = resolver(enabled: Self.allOn.subtracting(["topB"]))
        // mid-b (fully on, not top-level) must NOT protect shared
        #expect(r.disableSet("topA") == ["mid-a", "shared", "a-only"])
    }

    @Test("Disable set excludes already-disabled resources")
    func disableExcludesAlreadyOff() {
        let r = resolver(enabled: Self.allOn.subtracting(["a-only", "b-only"]))
        // topB partial (b-only off): no protection; a-only already off
        #expect(r.disableSet("topA") == ["mid-a", "shared"])
    }

    @Test("Fully-on top-level inside the target's dep tree anchors its own subtree")
    func disableAnchorInsideTree() {
        // Variant graph: topC (top_level, Tilt) is a dep of mid-a
        let graph = DependencyGraph(dependencies: [
            "topA": ["mid-a"],
            "mid-a": ["topC", "a-only"],
            "topC": ["shared"],
        ])
        let r = DependencyResolver(
            graph: graph,
            topLevel: ["topA", "topC"],
            existsInTilt: ["mid-a", "topC", "a-only", "shared"],
            enabled: ["mid-a", "topC", "a-only", "shared"]
        )
        // topC fully on: {topC, shared} survive; topA loses its exclusive parts
        #expect(r.disableSet("topA") == ["mid-a", "a-only"])
        // Disabling topC itself: topA is fully on and protects everything,
        // but explicit action wins for topC alone
        #expect(r.disableSet("topC") == ["topC"])
    }

    @Test("Disable set is empty when everything is already off")
    func disableSetEmptyWhenAllOff() {
        let r = resolver(enabled: [])
        #expect(r.disableSet("topA").isEmpty)
    }

    @Test("Cyclic graph terminates and disables the cycle")
    func disableCycle() {
        let graph = DependencyGraph(dependencies: ["a": ["b"], "b": ["a"]])
        let r = DependencyResolver(
            graph: graph, topLevel: [], existsInTilt: ["a", "b"], enabled: ["a", "b"]
        )
        #expect(r.state("a") == .on)
        #expect(r.disableSet("a") == ["a", "b"])
    }
}
