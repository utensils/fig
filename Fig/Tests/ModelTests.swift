import Foundation
import Testing
@testable import Fig

// MARK: - Test Fixtures

enum TestFixtures {
    static let permissionsJSON = """
    {
        "allow": ["Bash(npm run *)", "Read(src/**)"],
        "deny": ["Read(.env)", "Bash(curl *)"],
        "futureField": "preserved"
    }
    """

    static let attributionJSON = """
    {
        "commits": true,
        "pullRequests": false,
        "unknownField": 123
    }
    """

    static let hookDefinitionJSON = """
    {
        "type": "command",
        "command": "npm run lint",
        "timeout": 30
    }
    """

    static let hookGroupJSON = """
    {
        "matcher": "Bash(*)",
        "hooks": [
            { "type": "command", "command": "npm run lint" }
        ],
        "priority": 1
    }
    """

    static let mcpServerStdioJSON = """
    {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": { "GITHUB_TOKEN": "test-token" },
        "customOption": true
    }
    """

    static let mcpServerHTTPJSON = """
    {
        "type": "http",
        "url": "https://mcp.example.com/api",
        "headers": { "Authorization": "Bearer token" }
    }
    """

    static let mcpConfigJSON = """
    {
        "mcpServers": {
            "github": {
                "command": "npx",
                "args": ["-y", "@modelcontextprotocol/server-github"],
                "env": { "GITHUB_TOKEN": "test-token" }
            },
            "remote": {
                "type": "http",
                "url": "https://mcp.example.com/api"
            }
        },
        "version": "1.0"
    }
    """

    static let claudeSettingsJSON = """
    {
        "permissions": {
            "allow": ["Bash(npm run *)"],
            "deny": ["Read(.env)"]
        },
        "env": {
            "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16384"
        },
        "hooks": {
            "PreToolUse": [
                { "matcher": "Bash(*)", "hooks": [{ "type": "command", "command": "echo pre" }] }
            ]
        },
        "disallowedTools": ["DangerousTool"],
        "attribution": {
            "commits": true,
            "pullRequests": true
        },
        "experimentalFeature": "enabled"
    }
    """

    static let projectEntryJSON = """
    {
        "allowedTools": ["Bash", "Read", "Write"],
        "hasTrustDialogAccepted": true,
        "history": ["conv-1", "conv-2"],
        "mcpServers": {
            "local": { "command": "node", "args": ["server.js"] }
        },
        "customData": { "nested": "value" }
    }
    """

    static let legacyConfigJSON = """
    {
        "projects": {
            "/path/to/project": {
                "allowedTools": ["Bash", "Read"],
                "hasTrustDialogAccepted": true
            }
        },
        "customApiKeyResponses": {
            "key1": "response1"
        },
        "preferences": {
            "theme": "dark"
        },
        "mcpServers": {
            "global-server": { "command": "npx", "args": ["server"] }
        },
        "analytics": false
    }
    """
}

// MARK: - AnyCodable Tests

@Suite("AnyCodable Tests")
struct AnyCodableTests {
    @Test("Decodes and encodes primitive types")
    func primitiveTypes() throws {
        let json = """
        {
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "null": null
        }
        """

        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json.data(using: .utf8)!)

        #expect(decoded["string"]?.value as? String == "hello")
        #expect(decoded["int"]?.value as? Int == 42)
        #expect(decoded["double"]?.value as? Double == 3.14)
        #expect(decoded["bool"]?.value as? Bool == true)
        #expect(decoded["null"]?.value is NSNull)

        // Round-trip
        let encoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)
        #expect(decoded == redecoded)
    }

    @Test("Decodes and encodes nested structures")
    func nestedStructures() throws {
        let json = """
        {
            "array": [1, 2, 3],
            "object": { "key": "value" }
        }
        """

        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json.data(using: .utf8)!)

        if let array = decoded["array"]?.value as? [Any] {
            #expect(array.count == 3)
        } else {
            Issue.record("Array not decoded properly")
        }

        if let object = decoded["object"]?.value as? [String: Any] {
            #expect(object["key"] as? String == "value")
        } else {
            Issue.record("Object not decoded properly")
        }

        // Round-trip
        let encoded = try JSONEncoder().encode(decoded)
        let redecoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)
        #expect(decoded == redecoded)
    }

    @Test("Supports literal initialization")
    func literalInitialization() {
        let _: AnyCodable = "string"
        let _: AnyCodable = 42
        let _: AnyCodable = 3.14
        let _: AnyCodable = true
        let _: AnyCodable = nil
        let _: AnyCodable = [1, 2, 3]
        let _: AnyCodable = ["key": "value"]
    }
}

// MARK: - Permissions Tests

@Suite("Permissions Tests")
struct PermissionsTests {
    @Test("Decodes permissions with allow and deny arrays")
    func decodesPermissions() throws {
        let decoded = try JSONDecoder().decode(
            Permissions.self,
            from: TestFixtures.permissionsJSON.data(using: .utf8)!
        )

        #expect(decoded.allow == ["Bash(npm run *)", "Read(src/**)"])
        #expect(decoded.deny == ["Read(.env)", "Bash(curl *)"])
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            Permissions.self,
            from: TestFixtures.permissionsJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["futureField"]?.value as? String == "preserved")
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            Permissions.self,
            from: TestFixtures.permissionsJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Permissions.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - Attribution Tests

@Suite("Attribution Tests")
struct AttributionTests {
    @Test("Decodes attribution settings")
    func decodesAttribution() throws {
        let decoded = try JSONDecoder().decode(
            Attribution.self,
            from: TestFixtures.attributionJSON.data(using: .utf8)!
        )

        #expect(decoded.commits == true)
        #expect(decoded.pullRequests == false)
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            Attribution.self,
            from: TestFixtures.attributionJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["unknownField"]?.value as? Int == 123)
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            Attribution.self,
            from: TestFixtures.attributionJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Attribution.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - HookDefinition Tests

@Suite("HookDefinition Tests")
struct HookDefinitionTests {
    @Test("Decodes hook definition")
    func decodesHookDefinition() throws {
        let decoded = try JSONDecoder().decode(
            HookDefinition.self,
            from: TestFixtures.hookDefinitionJSON.data(using: .utf8)!
        )

        #expect(decoded.type == "command")
        #expect(decoded.command == "npm run lint")
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            HookDefinition.self,
            from: TestFixtures.hookDefinitionJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["timeout"]?.value as? Int == 30)
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            HookDefinition.self,
            from: TestFixtures.hookDefinitionJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HookDefinition.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - HookGroup Tests

@Suite("HookGroup Tests")
struct HookGroupTests {
    @Test("Decodes hook group with matcher and hooks")
    func decodesHookGroup() throws {
        let decoded = try JSONDecoder().decode(
            HookGroup.self,
            from: TestFixtures.hookGroupJSON.data(using: .utf8)!
        )

        #expect(decoded.matcher == "Bash(*)")
        #expect(decoded.hooks?.count == 1)
        #expect(decoded.hooks?.first?.type == "command")
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            HookGroup.self,
            from: TestFixtures.hookGroupJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["priority"]?.value as? Int == 1)
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            HookGroup.self,
            from: TestFixtures.hookGroupJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HookGroup.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - MCPServer Tests

@Suite("MCPServer Tests")
struct MCPServerTests {
    @Test("Decodes stdio server")
    func decodesStdioServer() throws {
        let decoded = try JSONDecoder().decode(
            MCPServer.self,
            from: TestFixtures.mcpServerStdioJSON.data(using: .utf8)!
        )

        #expect(decoded.command == "npx")
        #expect(decoded.args == ["-y", "@modelcontextprotocol/server-github"])
        #expect(decoded.env?["GITHUB_TOKEN"] == "test-token")
        #expect(decoded.isStdio == true)
        #expect(decoded.isHTTP == false)
    }

    @Test("Decodes HTTP server")
    func decodesHTTPServer() throws {
        let decoded = try JSONDecoder().decode(
            MCPServer.self,
            from: TestFixtures.mcpServerHTTPJSON.data(using: .utf8)!
        )

        #expect(decoded.type == "http")
        #expect(decoded.url == "https://mcp.example.com/api")
        #expect(decoded.headers?["Authorization"] == "Bearer token")
        #expect(decoded.isStdio == false)
        #expect(decoded.isHTTP == true)
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            MCPServer.self,
            from: TestFixtures.mcpServerStdioJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["customOption"]?.value as? Bool == true)
    }

    @Test("Static factory methods work correctly")
    func factoryMethods() {
        let stdio = MCPServer.stdio(command: "node", args: ["server.js"], env: ["PORT": "3000"])
        #expect(stdio.isStdio == true)
        #expect(stdio.command == "node")

        let http = MCPServer.http(url: "https://api.example.com", headers: ["X-Key": "abc"])
        #expect(http.isHTTP == true)
        #expect(http.url == "https://api.example.com")
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            MCPServer.self,
            from: TestFixtures.mcpServerStdioJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPServer.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - MCPConfig Tests

@Suite("MCPConfig Tests")
struct MCPConfigTests {
    @Test("Decodes MCP config with multiple servers")
    func decodesMCPConfig() throws {
        let decoded = try JSONDecoder().decode(
            MCPConfig.self,
            from: TestFixtures.mcpConfigJSON.data(using: .utf8)!
        )

        #expect(decoded.serverNames.count == 2)
        #expect(decoded.server(named: "github")?.command == "npx")
        #expect(decoded.server(named: "remote")?.isHTTP == true)
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            MCPConfig.self,
            from: TestFixtures.mcpConfigJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["version"]?.value as? String == "1.0")
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            MCPConfig.self,
            from: TestFixtures.mcpConfigJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPConfig.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - ClaudeSettings Tests

@Suite("ClaudeSettings Tests")
struct ClaudeSettingsTests {
    @Test("Decodes complete settings")
    func decodesClaudeSettings() throws {
        let decoded = try JSONDecoder().decode(
            ClaudeSettings.self,
            from: TestFixtures.claudeSettingsJSON.data(using: .utf8)!
        )

        #expect(decoded.permissions?.allow == ["Bash(npm run *)"])
        #expect(decoded.permissions?.deny == ["Read(.env)"])
        #expect(decoded.env?["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] == "16384")
        #expect(decoded.hooks(for: "PreToolUse")?.count == 1)
        #expect(decoded.disallowedTools == ["DangerousTool"])
        #expect(decoded.isToolDisallowed("DangerousTool") == true)
        #expect(decoded.isToolDisallowed("SafeTool") == false)
        #expect(decoded.attribution?.commits == true)
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            ClaudeSettings.self,
            from: TestFixtures.claudeSettingsJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["experimentalFeature"]?.value as? String == "enabled")
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            ClaudeSettings.self,
            from: TestFixtures.claudeSettingsJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClaudeSettings.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - ProjectEntry Tests

@Suite("ProjectEntry Tests")
struct ProjectEntryTests {
    @Test("Decodes project entry")
    func decodesProjectEntry() throws {
        let decoded = try JSONDecoder().decode(
            ProjectEntry.self,
            from: TestFixtures.projectEntryJSON.data(using: .utf8)!
        )

        #expect(decoded.allowedTools == ["Bash", "Read", "Write"])
        #expect(decoded.hasTrustDialogAccepted == true)
        #expect(decoded.history == ["conv-1", "conv-2"])
        #expect(decoded.hasMCPServers == true)
    }

    @Test("Computes name from path")
    func computesName() {
        var entry = ProjectEntry()
        entry.path = "/Users/test/projects/my-app"
        #expect(entry.name == "my-app")
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            ProjectEntry.self,
            from: TestFixtures.projectEntryJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["customData"] != nil)
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            ProjectEntry.self,
            from: TestFixtures.projectEntryJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectEntry.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - LegacyConfig Tests

@Suite("LegacyConfig Tests")
struct LegacyConfigTests {
    @Test("Decodes legacy config")
    func decodesLegacyConfig() throws {
        let decoded = try JSONDecoder().decode(
            LegacyConfig.self,
            from: TestFixtures.legacyConfigJSON.data(using: .utf8)!
        )

        #expect(decoded.projectPaths == ["/path/to/project"])
        #expect(decoded.project(at: "/path/to/project")?.hasTrustDialogAccepted == true)
        #expect(decoded.globalServerNames == ["global-server"])
        #expect(decoded.globalServer(named: "global-server")?.command == "npx")
    }

    @Test("Returns all projects with paths set")
    func allProjectsWithPaths() throws {
        let decoded = try JSONDecoder().decode(
            LegacyConfig.self,
            from: TestFixtures.legacyConfigJSON.data(using: .utf8)!
        )

        let projects = decoded.allProjects
        #expect(projects.count == 1)
        #expect(projects.first?.path == "/path/to/project")
    }

    @Test("Preserves unknown keys")
    func preservesUnknownKeys() throws {
        let decoded = try JSONDecoder().decode(
            LegacyConfig.self,
            from: TestFixtures.legacyConfigJSON.data(using: .utf8)!
        )

        #expect(decoded.additionalProperties?["analytics"]?.value as? Bool == false)
    }

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = try JSONDecoder().decode(
            LegacyConfig.self,
            from: TestFixtures.legacyConfigJSON.data(using: .utf8)!
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegacyConfig.self, from: encoded)

        #expect(original == decoded)
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Sendable Conformance Tests")
struct SendableTests {
    @Test("All models conform to Sendable")
    func sendableConformance() async {
        // These compile-time checks ensure Sendable conformance
        let _: any Sendable = AnyCodable("test")
        let _: any Sendable = Permissions()
        let _: any Sendable = Attribution()
        let _: any Sendable = HookDefinition()
        let _: any Sendable = HookGroup()
        let _: any Sendable = MCPServer()
        let _: any Sendable = MCPConfig()
        let _: any Sendable = ClaudeSettings()
        let _: any Sendable = ProjectEntry()
        let _: any Sendable = LegacyConfig()
    }
}
