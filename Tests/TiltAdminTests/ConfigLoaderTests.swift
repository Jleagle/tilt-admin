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
