@testable import Fig
import Foundation
import Testing

// MARK: - ProjectDiscoveryServiceTests

@Suite("ProjectDiscoveryService Tests")
struct ProjectDiscoveryServiceTests {
    // MARK: - DiscoveredProject Tests

    @Suite("DiscoveredProject Tests")
    struct DiscoveredProjectTests {
        @Test("Initializes with all properties")
        func initialization() {
            let date = Date()
            let project = DiscoveredProject(
                path: "/Users/test/projects/my-app",
                displayName: "my-app",
                exists: true,
                hasSettings: true,
                hasLocalSettings: false,
                hasMCPConfig: true,
                lastModified: date
            )

            #expect(project.path == "/Users/test/projects/my-app")
            #expect(project.displayName == "my-app")
            #expect(project.exists == true)
            #expect(project.hasSettings == true)
            #expect(project.hasLocalSettings == false)
            #expect(project.hasMCPConfig == true)
            #expect(project.lastModified == date)
        }

        @Test("ID equals path")
        func idEqualsPath() {
            let project = DiscoveredProject(
                path: "/path/to/project",
                displayName: "project",
                exists: true,
                hasSettings: false,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: nil
            )

            #expect(project.id == "/path/to/project")
        }

        @Test("URL property returns correct URL")
        func urlProperty() {
            let project = DiscoveredProject(
                path: "/Users/test/my-project",
                displayName: "my-project",
                exists: true,
                hasSettings: false,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: nil
            )

            #expect(project.url.path == "/Users/test/my-project")
        }

        @Test("hasAnyConfig returns true when any config exists")
        func hasAnyConfigWithSettings() {
            let project = DiscoveredProject(
                path: "/path",
                displayName: "test",
                exists: true,
                hasSettings: true,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: nil
            )

            #expect(project.hasAnyConfig == true)
        }

        @Test("hasAnyConfig returns true for local settings")
        func hasAnyConfigWithLocalSettings() {
            let project = DiscoveredProject(
                path: "/path",
                displayName: "test",
                exists: true,
                hasSettings: false,
                hasLocalSettings: true,
                hasMCPConfig: false,
                lastModified: nil
            )

            #expect(project.hasAnyConfig == true)
        }

        @Test("hasAnyConfig returns true for MCP config")
        func hasAnyConfigWithMCP() {
            let project = DiscoveredProject(
                path: "/path",
                displayName: "test",
                exists: true,
                hasSettings: false,
                hasLocalSettings: false,
                hasMCPConfig: true,
                lastModified: nil
            )

            #expect(project.hasAnyConfig == true)
        }

        @Test("hasAnyConfig returns false when no config exists")
        func hasAnyConfigFalse() {
            let project = DiscoveredProject(
                path: "/path",
                displayName: "test",
                exists: true,
                hasSettings: false,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: nil
            )

            #expect(project.hasAnyConfig == false)
        }

        @Test("Projects with same path are equal")
        func equality() {
            let date = Date()
            let project1 = DiscoveredProject(
                path: "/path/to/project",
                displayName: "project",
                exists: true,
                hasSettings: true,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: date
            )
            let project2 = DiscoveredProject(
                path: "/path/to/project",
                displayName: "project",
                exists: true,
                hasSettings: true,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: date
            )

            #expect(project1 == project2)
        }

        @Test("Projects are hashable")
        func hashability() {
            let project = DiscoveredProject(
                path: "/path/to/project",
                displayName: "project",
                exists: true,
                hasSettings: false,
                hasLocalSettings: false,
                hasMCPConfig: false,
                lastModified: nil
            )

            var set = Set<DiscoveredProject>()
            set.insert(project)

            #expect(set.contains(project))
        }
    }

    // MARK: - Discovery Integration Tests

    @Suite("Discovery Integration Tests")
    struct DiscoveryIntegrationTests {
        @Test("Builds project metadata from filesystem path")
        func buildsProjectFromPath() async throws {
            // Create temporary directory structure
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            // Create mock home directory with .claude.json
            let mockHome = tempDir.appendingPathComponent("home")
            try FileManager.default.createDirectory(at: mockHome, withIntermediateDirectories: true)

            // Create a mock project directory
            let projectDir = tempDir.appendingPathComponent("projects/my-app")
            let claudeDir = projectDir.appendingPathComponent(".claude")
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            // Create settings file
            let settingsData = """
            {
                "permissions": { "allow": ["Bash(*)"] }
            }
            """.data(using: .utf8)!
            try settingsData.write(to: claudeDir.appendingPathComponent("settings.json"))

            // Test the buildDiscoveredProject method directly
            let service = ProjectDiscoveryService()
            let project = await service.refreshProject(at: projectDir.path)

            #expect(project != nil)
            #expect(project?.displayName == "my-app")
            #expect(project?.exists == true)
            #expect(project?.hasSettings == true)
            #expect(project?.hasLocalSettings == false)
        }

        @Test("Handles non-existent project gracefully")
        func handlesMissingProject() async {
            let service = ProjectDiscoveryService()
            let project = await service.refreshProject(at: "/nonexistent/path/12345")

            #expect(project != nil)
            #expect(project?.exists == false)
            #expect(project?.hasSettings == false)
        }

        @Test("Detects MCP config file")
        func detectsMCPConfig() async throws {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Create .mcp.json
            let mcpData = """
            { "mcpServers": {} }
            """.data(using: .utf8)!
            try mcpData.write(to: tempDir.appendingPathComponent(".mcp.json"))

            let service = ProjectDiscoveryService()
            let project = await service.refreshProject(at: tempDir.path)

            #expect(project?.hasMCPConfig == true)
            #expect(project?.hasSettings == false)
        }

        @Test("Detects local settings file")
        func detectsLocalSettings() async throws {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let claudeDir = tempDir.appendingPathComponent(".claude")
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            // Create settings.local.json
            let localData = """
            { "env": { "DEBUG": "true" } }
            """.data(using: .utf8)!
            try localData.write(to: claudeDir.appendingPathComponent("settings.local.json"))

            let service = ProjectDiscoveryService()
            let project = await service.refreshProject(at: tempDir.path)

            #expect(project?.hasLocalSettings == true)
            #expect(project?.hasSettings == false)
        }
    }

    // MARK: - Default Scan Directories Tests

    @Suite("Default Scan Directories Tests")
    struct DefaultScanDirectoriesTests {
        @Test("Includes common development directories")
        func includesCommonDirectories() {
            let defaults = ProjectDiscoveryService.defaultScanDirectories

            #expect(defaults.contains("~"))
            #expect(defaults.contains("~/code"))
            #expect(defaults.contains("~/Code"))
            #expect(defaults.contains("~/projects"))
            #expect(defaults.contains("~/Projects"))
            #expect(defaults.contains("~/Developer"))
        }
    }
}
