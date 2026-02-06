@testable import Fig
import Foundation
import Testing

// MARK: - MCPSharingServiceTests

@Suite("MCP Sharing Service Tests")
struct MCPSharingServiceTests {
    let service = MCPSharingService.shared

    // MARK: - Serialization Tests

    @Test("Serializes servers to MCPConfig JSON format")
    func serializeToJSON() async throws {
        let servers: [String: MCPServer] = [
            "github": .stdio(command: "npx", args: ["-y", "@mcp/server-github"]),
            "api": .http(url: "https://mcp.example.com"),
        ]

        let json = try service.serializeToJSON(servers: servers)

        // Verify it's valid MCPConfig format
        let data = try #require(json.data(using: .utf8))
        let config = try JSONDecoder().decode(MCPConfig.self, from: data)
        #expect(config.mcpServers?.count == 2)
        #expect(config.mcpServers?["github"]?.command == "npx")
        #expect(config.mcpServers?["api"]?.url == "https://mcp.example.com")
    }

    @Test("Serialized JSON round-trips correctly")
    func serializationRoundTrip() async throws {
        let servers: [String: MCPServer] = [
            "github": .stdio(
                command: "npx",
                args: ["-y", "@mcp/server-github"],
                env: ["GITHUB_TOKEN": "tok-123"]
            ),
            "slack": .stdio(command: "npx", args: ["-y", "@mcp/server-slack"]),
        ]

        let json = try service.serializeToJSON(servers: servers)
        let parsed = try await service.parseServersFromJSON(json)

        #expect(parsed.count == 2)
        #expect(parsed["github"]?.command == "npx")
        #expect(parsed["github"]?.env?["GITHUB_TOKEN"] == "tok-123")
        #expect(parsed["slack"]?.command == "npx")
    }

    @Test("Serializes empty server dictionary")
    func serializeEmpty() async throws {
        let json = try service.serializeToJSON(servers: [:])
        let data = try #require(json.data(using: .utf8))
        let config = try JSONDecoder().decode(MCPConfig.self, from: data)
        #expect(config.mcpServers?.isEmpty == true)
    }

    @Test("Serialized JSON uses sorted keys")
    func serializeSortedKeys() async throws {
        let servers: [String: MCPServer] = [
            "zebra": .stdio(command: "z"),
            "alpha": .stdio(command: "a"),
        ]

        let json = try service.serializeToJSON(servers: servers)

        // "alpha" should appear before "zebra" in the output
        let alphaRange = try #require(json.range(of: "alpha"))
        let zebraRange = try #require(json.range(of: "zebra"))
        #expect(alphaRange.lowerBound < zebraRange.lowerBound)
    }

    // MARK: - Redaction Tests

    @Test("Redaction replaces sensitive env values with placeholders")
    func redactSensitiveEnv() async throws {
        let servers: [String: MCPServer] = [
            "github": .stdio(
                command: "npx",
                args: ["-y", "@mcp/server-github"],
                env: [
                    "GITHUB_TOKEN": "ghp_secret123",
                    "PATH": "/usr/local/bin",
                ]
            ),
        ]

        let json = try service.serializeToJSON(servers: servers, redactSensitive: true)
        let parsed = try await service.parseServersFromJSON(json)

        #expect(parsed["github"]?.env?["GITHUB_TOKEN"] == "<YOUR_GITHUB_TOKEN>")
        #expect(parsed["github"]?.env?["PATH"] == "/usr/local/bin")
    }

    @Test("Redaction replaces sensitive header values with placeholders")
    func redactSensitiveHeaders() async throws {
        let servers: [String: MCPServer] = [
            "api": .http(
                url: "https://example.com",
                headers: [
                    "Authorization": "Bearer secret",
                    "Content-Type": "application/json",
                ]
            ),
        ]

        let json = try service.serializeToJSON(servers: servers, redactSensitive: true)
        let parsed = try await service.parseServersFromJSON(json)

        #expect(parsed["api"]?.headers?["Authorization"] == "<YOUR_AUTHORIZATION>")
        #expect(parsed["api"]?.headers?["Content-Type"] == "application/json")
    }

    @Test("Redaction preserves non-sensitive values")
    func redactPreservesNonSensitive() async throws {
        let servers: [String: MCPServer] = [
            "safe": .stdio(
                command: "npx",
                env: [
                    "NODE_ENV": "production",
                    "DEBUG": "true",
                ]
            ),
        ]

        let json = try service.serializeToJSON(servers: servers, redactSensitive: true)
        let parsed = try await service.parseServersFromJSON(json)

        #expect(parsed["safe"]?.env?["NODE_ENV"] == "production")
        #expect(parsed["safe"]?.env?["DEBUG"] == "true")
    }

    @Test("Redaction without sensitive data returns same JSON")
    func redactNoSensitiveData() async throws {
        let servers: [String: MCPServer] = [
            "safe": .stdio(command: "echo", env: ["PATH": "/bin"]),
        ]

        let normalJSON = try service.serializeToJSON(servers: servers, redactSensitive: false)
        let redactedJSON = try service.serializeToJSON(servers: servers, redactSensitive: true)

        #expect(normalJSON == redactedJSON)
    }

    // MARK: - Parsing Tests

    @Test("Parses MCPConfig format")
    func parseMCPConfigFormat() async throws {
        let json = """
        {
            "mcpServers": {
                "github": {
                    "command": "npx",
                    "args": ["-y", "@mcp/server-github"],
                    "env": { "GITHUB_TOKEN": "tok" }
                },
                "api": {
                    "type": "http",
                    "url": "https://mcp.example.com"
                }
            }
        }
        """

        let servers = try await service.parseServersFromJSON(json)
        #expect(servers.count == 2)
        #expect(servers["github"]?.command == "npx")
        #expect(servers["github"]?.env?["GITHUB_TOKEN"] == "tok")
        #expect(servers["api"]?.url == "https://mcp.example.com")
    }

    @Test("Parses flat dictionary format")
    func parseFlatDictFormat() async throws {
        let json = """
        {
            "github": {
                "command": "npx",
                "args": ["-y", "@mcp/server-github"]
            },
            "slack": {
                "command": "npx",
                "args": ["-y", "@mcp/server-slack"]
            }
        }
        """

        let servers = try await service.parseServersFromJSON(json)
        #expect(servers.count == 2)
        #expect(servers["github"]?.command == "npx")
        #expect(servers["slack"]?.command == "npx")
    }

    @Test("Parses single named server")
    func parseSingleNamed() async throws {
        let json = """
        {
            "my-server": {
                "command": "npx",
                "args": ["-y", "some-server"]
            }
        }
        """

        let servers = try await service.parseServersFromJSON(json)
        #expect(servers.count == 1)
        #expect(servers["my-server"]?.command == "npx")
    }

    @Test("Parses single unnamed server")
    func parseSingleUnnamed() async throws {
        let json = """
        {
            "command": "npx",
            "args": ["-y", "@mcp/server-github"]
        }
        """

        let servers = try await service.parseServersFromJSON(json)
        #expect(servers.count == 1)
        #expect(servers["server"]?.command == "npx")
    }

    @Test("Parses single unnamed HTTP server")
    func parseSingleUnnamedHTTP() async throws {
        let json = """
        {
            "type": "http",
            "url": "https://mcp.example.com"
        }
        """

        let servers = try await service.parseServersFromJSON(json)
        #expect(servers.count == 1)
        #expect(servers["server"]?.url == "https://mcp.example.com")
    }

    @Test("Rejects invalid JSON")
    func parseInvalidJSON() async {
        do {
            _ = try await service.parseServersFromJSON("not json at all")
            Issue.record("Expected error for invalid JSON")
        } catch {
            #expect(error is MCPSharingError)
        }
    }

    @Test("Rejects empty JSON object")
    func parseEmptyObject() async {
        do {
            _ = try await service.parseServersFromJSON("{}")
            Issue.record("Expected error for empty JSON object")
        } catch {
            #expect(error is MCPSharingError)
        }
    }

    @Test("Rejects JSON array")
    func parseArray() async {
        do {
            _ = try await service.parseServersFromJSON("[1, 2, 3]")
            Issue.record("Expected error for JSON array")
        } catch {
            #expect(error is MCPSharingError)
        }
    }

    // MARK: - Sensitive Data Detection Tests

    @Test("Detects sensitive env vars across multiple servers")
    func detectSensitiveMultipleServers() async {
        let servers: [String: MCPServer] = [
            "github": .stdio(
                command: "npx",
                env: ["GITHUB_TOKEN": "tok", "PATH": "/bin"]
            ),
            "slack": .stdio(
                command: "npx",
                env: ["SLACK_API_KEY": "key"]
            ),
        ]

        let warnings = await service.detectSensitiveData(servers: servers)
        let warningKeys = warnings.map(\.key)

        #expect(warningKeys.contains("github.GITHUB_TOKEN"))
        #expect(warningKeys.contains("slack.SLACK_API_KEY"))
        #expect(!warningKeys.contains("github.PATH"))
    }

    @Test("Detects sensitive HTTP headers")
    func detectSensitiveHeaders() async {
        let servers: [String: MCPServer] = [
            "api": .http(
                url: "https://example.com",
                headers: [
                    "Authorization": "Bearer tok",
                    "Content-Type": "application/json",
                ]
            ),
        ]

        let warnings = await service.detectSensitiveData(servers: servers)
        let warningKeys = warnings.map(\.key)

        #expect(warningKeys.contains("api.Authorization"))
        #expect(!warningKeys.contains("api.Content-Type"))
    }

    @Test("Returns empty for servers without secrets")
    func noSensitiveData() async {
        let servers: [String: MCPServer] = [
            "safe": .stdio(command: "echo", env: ["NODE_ENV": "prod"]),
            "web": .http(url: "https://example.com"),
        ]

        let warnings = await service.detectSensitiveData(servers: servers)
        #expect(warnings.isEmpty)
    }

    @Test("containsSensitiveData returns correct boolean")
    func containsSensitiveDataBool() async {
        let withSecrets: [String: MCPServer] = [
            "gh": .stdio(command: "npx", env: ["GITHUB_TOKEN": "tok"]),
        ]
        let withoutSecrets: [String: MCPServer] = [
            "safe": .stdio(command: "echo"),
        ]

        #expect(await service.containsSensitiveData(servers: withSecrets) == true)
        #expect(await service.containsSensitiveData(servers: withoutSecrets) == false)
    }

    // MARK: - BulkImportResult Tests

    @Test("BulkImportResult summary formatting")
    func bulkImportResultSummary() {
        let result = BulkImportResult(
            imported: ["a", "b"],
            skipped: ["c"],
            renamed: ["d": "d-copy"],
            errors: []
        )

        #expect(result.totalImported == 3)
        #expect(result.summary.contains("2 imported"))
        #expect(result.summary.contains("1 renamed"))
        #expect(result.summary.contains("1 skipped"))
    }

    @Test("BulkImportResult empty summary")
    func bulkImportResultEmptySummary() {
        let result = BulkImportResult(
            imported: [],
            skipped: [],
            renamed: [:],
            errors: []
        )

        #expect(result.totalImported == 0)
        #expect(result.summary.isEmpty)
    }
}
