@testable import Fig
import Foundation
import Testing

@Suite("ConfigFileManager Tests")
struct ConfigFileManagerTests {
    // MARK: Lifecycle

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: Internal

    // MARK: - Path Tests

    @Suite("Path Resolution")
    struct PathTests {
        @Test("Global paths resolve correctly")
        func globalPaths() async {
            let manager = ConfigFileManager.shared
            let homeDir = FileManager.default.homeDirectoryForCurrentUser

            let globalConfig = await manager.globalConfigURL
            #expect(globalConfig == homeDir.appendingPathComponent(".claude.json"))

            let globalSettings = await manager.globalSettingsURL
            #expect(globalSettings == homeDir.appendingPathComponent(".claude/settings.json"))
        }

        @Test("Project paths resolve correctly")
        func projectPaths() async {
            let manager = ConfigFileManager.shared
            let projectPath = URL(fileURLWithPath: "/Users/test/myproject")

            let projectSettings = await manager.projectSettingsURL(for: projectPath)
            #expect(projectSettings.path == "/Users/test/myproject/.claude/settings.json")

            let localSettings = await manager.projectLocalSettingsURL(for: projectPath)
            #expect(localSettings.path == "/Users/test/myproject/.claude/settings.local.json")

            let mcpConfig = await manager.mcpConfigURL(for: projectPath)
            #expect(mcpConfig.path == "/Users/test/myproject/.mcp.json")
        }
    }

    let tempDirectory: URL

    // MARK: - Read/Write Tests

    @Test("Reads and writes ClaudeSettings")
    func readWriteSettings() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("settings.json")
        let manager = ConfigFileManager.shared

        // Write settings
        let settings = ClaudeSettings(
            permissions: Permissions(allow: ["Bash(*)"]),
            env: ["TEST_VAR": "test_value"],
            attribution: Attribution(commits: true)
        )
        try await manager.write(settings, to: testFile)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: testFile.path))

        // Read back
        let readSettings = try await manager.read(ClaudeSettings.self, from: testFile)
        #expect(readSettings != nil)
        #expect(readSettings?.permissions?.allow == ["Bash(*)"])
        #expect(readSettings?.env?["TEST_VAR"] == "test_value")
        #expect(readSettings?.attribution?.commits == true)
    }

    @Test("Reads and writes MCPConfig")
    func readWriteMCPConfig() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent(".mcp.json")
        let manager = ConfigFileManager.shared

        // Write config
        let config = MCPConfig(
            mcpServers: [
                "github": MCPServer.stdio(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-github"]
                ),
            ]
        )
        try await manager.write(config, to: testFile)

        // Read back
        let readConfig = try await manager.read(MCPConfig.self, from: testFile)
        #expect(readConfig != nil)
        #expect(readConfig?.mcpServers?["github"]?.command == "npx")
    }

    @Test("Returns nil for non-existent file")
    func readNonExistent() async throws {
        let manager = ConfigFileManager.shared
        let nonExistent = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID()).json")

        let result = try await manager.read(ClaudeSettings.self, from: nonExistent)
        #expect(result == nil)
    }

    @Test("Creates backup before overwriting")
    func createsBackup() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("settings.json")
        let manager = ConfigFileManager.shared

        // Write initial content
        let initial = ClaudeSettings(env: ["VERSION": "1"])
        try await manager.write(initial, to: testFile)

        // Write updated content (should create backup)
        let updated = ClaudeSettings(env: ["VERSION": "2"])
        try await manager.write(updated, to: testFile)

        // Check for backup file
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let backups = contents.filter { $0.lastPathComponent.contains(".backup.") }
        #expect(backups.count >= 1)
    }

    @Test("Creates parent directories when writing")
    func createsParentDirectories() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let nestedFile = tempDir
            .appendingPathComponent("nested")
            .appendingPathComponent("deep")
            .appendingPathComponent("settings.json")
        let manager = ConfigFileManager.shared

        let settings = ClaudeSettings(env: ["TEST": "value"])
        try await manager.write(settings, to: nestedFile)

        #expect(FileManager.default.fileExists(atPath: nestedFile.path))
    }

    // MARK: - Error Handling Tests

    @Test("Throws on invalid JSON")
    func invalidJSON() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("invalid.json")

        // Write invalid JSON
        try "{ invalid json }".write(to: testFile, atomically: true, encoding: .utf8)

        let manager = ConfigFileManager.shared

        await #expect(throws: ConfigFileError.self) {
            _ = try await manager.read(ClaudeSettings.self, from: testFile)
        }
    }

    // MARK: - File Existence Tests

    @Test("fileExists returns correct values")
    func fileExistsCheck() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let existingFile = tempDir.appendingPathComponent("exists.json")
        try "{}".write(to: existingFile, atomically: true, encoding: .utf8)

        let nonExistentFile = tempDir.appendingPathComponent("nonexistent.json")

        let manager = ConfigFileManager.shared

        let existsResult = await manager.fileExists(at: existingFile)
        #expect(existsResult == true)

        let notExistsResult = await manager.fileExists(at: nonExistentFile)
        #expect(notExistsResult == false)
    }
}
