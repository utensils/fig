@testable import Fig
import Foundation
import Testing

// MARK: - HealthCheckTestHelpers

enum HealthCheckTestHelpers {
    /// Creates a minimal context for testing with optional overrides.
    static func makeContext(
        globalSettings: ClaudeSettings? = nil,
        projectSettings: ClaudeSettings? = nil,
        projectLocalSettings: ClaudeSettings? = nil,
        mcpConfig: MCPConfig? = nil,
        legacyConfig: LegacyConfig? = nil,
        localSettingsExists: Bool = false,
        mcpConfigExists: Bool = false,
        globalConfigFileSize: Int64? = nil
    ) -> HealthCheckContext {
        HealthCheckContext(
            projectPath: URL(fileURLWithPath: "/tmp/test-project"),
            globalSettings: globalSettings,
            projectSettings: projectSettings,
            projectLocalSettings: projectLocalSettings,
            mcpConfig: mcpConfig,
            legacyConfig: legacyConfig,
            localSettingsExists: localSettingsExists,
            mcpConfigExists: mcpConfigExists,
            globalConfigFileSize: globalConfigFileSize
        )
    }
}

// MARK: - DenyListSecurityCheckTests

@Suite("DenyListSecurityCheck Tests")
struct DenyListSecurityCheckTests {
    let check = DenyListSecurityCheck()

    @Test("Flags missing .env deny rule")
    func flagsMissingEnvDeny() {
        let context = HealthCheckTestHelpers.makeContext()
        let findings = self.check.check(context: context)

        let envFinding = findings.first { $0.title.contains(".env") }
        #expect(envFinding != nil)
        #expect(envFinding?.severity == .security)
        #expect(envFinding?.autoFix == .addToDenyList(pattern: "Read(.env)"))
    }

    @Test("Flags missing secrets/ deny rule")
    func flagsMissingSecretsDeny() {
        let context = HealthCheckTestHelpers.makeContext()
        let findings = self.check.check(context: context)

        let secretsFinding = findings.first { $0.title.contains("secrets/") }
        #expect(secretsFinding != nil)
        #expect(secretsFinding?.severity == .security)
        #expect(secretsFinding?.autoFix == .addToDenyList(pattern: "Read(secrets/**)"))
    }

    @Test("No findings when .env is in deny list")
    func noFindingWhenEnvDenied() {
        let settings = ClaudeSettings(permissions: Permissions(deny: ["Read(.env)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        let envFinding = findings.first { $0.title.contains(".env") }
        #expect(envFinding == nil)
    }

    @Test("No findings when secrets is in deny list")
    func noFindingWhenSecretsDenied() {
        let settings = ClaudeSettings(permissions: Permissions(deny: ["Read(secrets/**)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        let secretsFinding = findings.first { $0.title.contains("secrets/") }
        #expect(secretsFinding == nil)
    }

    @Test("Checks deny rules across all config sources")
    func checksAllSources() {
        let global = ClaudeSettings(permissions: Permissions(deny: ["Read(.env)"]))
        let local = ClaudeSettings(permissions: Permissions(deny: ["Read(secrets/**)"]))
        let context = HealthCheckTestHelpers.makeContext(
            globalSettings: global,
            projectLocalSettings: local
        )
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - BroadAllowRulesCheckTests

@Suite("BroadAllowRulesCheck Tests")
struct BroadAllowRulesCheckTests {
    let check = BroadAllowRulesCheck()

    @Test("Flags Bash(*) as overly broad")
    func flagsBroadBash() {
        let settings = ClaudeSettings(permissions: Permissions(allow: ["Bash(*)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        #expect(findings.count == 1)
        #expect(findings.first?.severity == .warning)
        #expect(findings.first?.title.contains("Bash(*)") == true)
    }

    @Test("Does not flag specific allow rules")
    func doesNotFlagSpecific() {
        let settings = ClaudeSettings(permissions: Permissions(allow: ["Bash(npm run *)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }

    @Test("Flags multiple broad rules")
    func flagsMultipleBroad() {
        let settings = ClaudeSettings(permissions: Permissions(allow: ["Bash(*)", "Read(*)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        #expect(findings.count == 2)
    }

    @Test("No auto-fix for broad rules")
    func noAutoFix() {
        let settings = ClaudeSettings(permissions: Permissions(allow: ["Bash(*)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        #expect(findings.first?.autoFix == nil)
    }
}

// MARK: - GlobalConfigSizeCheckTests

@Suite("GlobalConfigSizeCheck Tests")
struct GlobalConfigSizeCheckTests {
    let check = GlobalConfigSizeCheck()

    @Test("Flags config larger than 5MB")
    func flagsLargeConfig() {
        let size: Int64 = 6 * 1024 * 1024 // 6 MB
        let context = HealthCheckTestHelpers.makeContext(globalConfigFileSize: size)
        let findings = self.check.check(context: context)

        #expect(findings.count == 1)
        #expect(findings.first?.severity == .warning)
        #expect(findings.first?.title.contains("6.0 MB") == true)
    }

    @Test("No finding for small config")
    func noFindingForSmall() {
        let size: Int64 = 1024 // 1 KB
        let context = HealthCheckTestHelpers.makeContext(globalConfigFileSize: size)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }

    @Test("No finding when size is unknown")
    func noFindingWhenUnknown() {
        let context = HealthCheckTestHelpers.makeContext(globalConfigFileSize: nil)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - MCPHardcodedSecretsCheckTests

@Suite("MCPHardcodedSecretsCheck Tests")
struct MCPHardcodedSecretsCheckTests {
    let check = MCPHardcodedSecretsCheck()

    @Test("Flags hardcoded token in env var")
    func flagsHardcodedToken() {
        let server = MCPServer(command: "npx", env: ["GITHUB_TOKEN": "ghp_1234567890abcdef"])
        let config = MCPConfig(mcpServers: ["github": server])
        let context = HealthCheckTestHelpers.makeContext(mcpConfig: config)
        let findings = self.check.check(context: context)

        #expect(!findings.isEmpty)
        #expect(findings.first?.severity == .warning)
    }

    @Test("Flags secret-looking key with long value")
    func flagsSecretKey() {
        let server = MCPServer(command: "npx", env: ["API_KEY": "some-long-api-key-value"])
        let config = MCPConfig(mcpServers: ["test": server])
        let context = HealthCheckTestHelpers.makeContext(mcpConfig: config)
        let findings = self.check.check(context: context)

        #expect(!findings.isEmpty)
    }

    @Test("Does not flag non-secret env vars")
    func doesNotFlagNonSecret() {
        let server = MCPServer(command: "npx", env: ["NODE_ENV": "production"])
        let config = MCPConfig(mcpServers: ["test": server])
        let context = HealthCheckTestHelpers.makeContext(mcpConfig: config)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }

    @Test("Flags secrets in HTTP headers")
    func flagsHeaderSecrets() {
        let server = MCPServer(type: "http", url: "https://example.com", headers: [
            "Authorization": "Bearer sk-1234567890abcdef",
        ])
        let config = MCPConfig(mcpServers: ["remote": server])
        let context = HealthCheckTestHelpers.makeContext(mcpConfig: config)
        let findings = self.check.check(context: context)

        #expect(!findings.isEmpty)
    }

    @Test("No findings when no MCP servers")
    func noFindingsNoServers() {
        let context = HealthCheckTestHelpers.makeContext()
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - LocalSettingsCheckTests

@Suite("LocalSettingsCheck Tests")
struct LocalSettingsCheckTests {
    let check = LocalSettingsCheck()

    @Test("Suggests creating local settings when missing")
    func suggestsCreation() {
        let context = HealthCheckTestHelpers.makeContext(localSettingsExists: false)
        let findings = self.check.check(context: context)

        #expect(findings.count == 1)
        #expect(findings.first?.severity == .suggestion)
        #expect(findings.first?.autoFix == .createLocalSettings)
    }

    @Test("No finding when local settings exist")
    func noFindingWhenExists() {
        let context = HealthCheckTestHelpers.makeContext(localSettingsExists: true)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - MCPScopingCheckTests

@Suite("MCPScopingCheck Tests")
struct MCPScopingCheckTests {
    let check = MCPScopingCheck()

    @Test("Suggests scoping when global servers exist without project MCP")
    func suggestsScoping() {
        let legacy = LegacyConfig(mcpServers: [
            "github": MCPServer(command: "npx"),
        ])
        let context = HealthCheckTestHelpers.makeContext(
            legacyConfig: legacy,
            mcpConfigExists: false
        )
        let findings = self.check.check(context: context)

        #expect(findings.count == 1)
        #expect(findings.first?.severity == .suggestion)
    }

    @Test("No finding when project MCP exists")
    func noFindingWithProjectMCP() {
        let legacy = LegacyConfig(mcpServers: [
            "github": MCPServer(command: "npx"),
        ])
        let context = HealthCheckTestHelpers.makeContext(
            legacyConfig: legacy,
            mcpConfigExists: true
        )
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }

    @Test("No finding when no global servers")
    func noFindingNoGlobalServers() {
        let context = HealthCheckTestHelpers.makeContext(mcpConfigExists: false)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - HookSuggestionsCheckTests

@Suite("HookSuggestionsCheck Tests")
struct HookSuggestionsCheckTests {
    let check = HookSuggestionsCheck()

    @Test("Suggests hooks when none configured")
    func suggestsHooks() {
        let context = HealthCheckTestHelpers.makeContext()
        let findings = self.check.check(context: context)

        #expect(findings.count == 1)
        #expect(findings.first?.severity == .suggestion)
    }

    @Test("No finding when hooks exist")
    func noFindingWithHooks() {
        let hooks: [String: [HookGroup]] = [
            "PreToolUse": [HookGroup(hooks: [HookDefinition(type: "command", command: "npm run lint")])],
        ]
        let settings = ClaudeSettings(hooks: hooks)
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - GoodPracticesCheckTests

@Suite("GoodPracticesCheck Tests")
struct GoodPracticesCheckTests {
    let check = GoodPracticesCheck()

    @Test("Reports good practice for .env in deny list")
    func reportsEnvProtection() {
        let settings = ClaudeSettings(permissions: Permissions(deny: ["Read(.env)"]))
        let context = HealthCheckTestHelpers.makeContext(projectSettings: settings)
        let findings = self.check.check(context: context)

        let envFinding = findings.first { $0.title.contains("Sensitive files protected") }
        #expect(envFinding != nil)
        #expect(envFinding?.severity == .good)
    }

    @Test("Reports good practice for local settings")
    func reportsLocalSettings() {
        let context = HealthCheckTestHelpers.makeContext(localSettingsExists: true)
        let findings = self.check.check(context: context)

        let localFinding = findings.first { $0.title.contains("Local settings") }
        #expect(localFinding != nil)
        #expect(localFinding?.severity == .good)
    }

    @Test("Reports good practice for project MCP")
    func reportsProjectMCP() {
        let context = HealthCheckTestHelpers.makeContext(mcpConfigExists: true)
        let findings = self.check.check(context: context)

        let mcpFinding = findings.first { $0.title.contains("Project-scoped MCP") }
        #expect(mcpFinding != nil)
        #expect(mcpFinding?.severity == .good)
    }

    @Test("No good practices for empty config")
    func noGoodPracticesEmpty() {
        let context = HealthCheckTestHelpers.makeContext()
        let findings = self.check.check(context: context)

        #expect(findings.isEmpty)
    }
}

// MARK: - WellConfiguredProjectTests

@Suite("Well-Configured Project Tests")
struct WellConfiguredProjectTests {
    @Test("No false positives on well-configured project")
    func noFalsePositives() {
        let settings = ClaudeSettings(
            permissions: Permissions(
                allow: ["Bash(npm run *)", "Read(src/**)"],
                deny: ["Read(.env)", "Read(secrets/**)"]
            ),
            hooks: [
                "PreToolUse": [HookGroup(hooks: [HookDefinition(type: "command", command: "npm run lint")])],
            ]
        )
        let mcpConfig = MCPConfig(mcpServers: [
            "test": MCPServer(command: "npx", env: ["NODE_ENV": "production"]),
        ])

        let context = HealthCheckTestHelpers.makeContext(
            projectSettings: settings,
            mcpConfig: mcpConfig,
            localSettingsExists: true,
            mcpConfigExists: true,
            globalConfigFileSize: 1024
        )

        let allChecks: [any HealthCheck] = [
            DenyListSecurityCheck(),
            BroadAllowRulesCheck(),
            GlobalConfigSizeCheck(),
            MCPHardcodedSecretsCheck(),
            LocalSettingsCheck(),
            MCPScopingCheck(),
            HookSuggestionsCheck(),
            GoodPracticesCheck(),
        ]
        let findings = allChecks.flatMap { $0.check(context: context) }

        // Should have no security or warning findings
        let problems = findings.filter { $0.severity == .security || $0.severity == .warning }
        #expect(problems.isEmpty, "Expected no security/warning findings but got: \(problems.map(\.title))")

        // Should have good findings
        let good = findings.filter { $0.severity == .good }
        #expect(!good.isEmpty)
    }
}
