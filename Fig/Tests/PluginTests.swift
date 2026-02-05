@testable import Fig
import Foundation
import Testing

// MARK: - PluginTestFixtures

enum PluginTestFixtures {
    static let validManifestJSON = """
    {
        "id": "com.example.test-plugin",
        "name": "Test Plugin",
        "version": "1.0.0",
        "author": {
            "name": "Test Author",
            "email": "test@example.com"
        },
        "summary": "A test plugin for unit testing",
        "category": "health-checks",
        "main": "init.lua",
        "capabilities": ["health:register", "config:read:global"],
        "hooks": [
            { "event": "PreToolUse", "handler": "on_pre_tool" }
        ]
    }
    """

    static let minimalManifestJSON = """
    {
        "id": "minimal.plugin",
        "name": "Minimal",
        "version": "0.1.0",
        "author": { "name": "Someone" },
        "summary": "Minimal plugin",
        "category": "other",
        "main": "main.lua"
    }
    """

    static let manifestWithUnknownFieldsJSON = """
    {
        "id": "com.example.future",
        "name": "Future Plugin",
        "version": "2.0.0",
        "author": { "name": "Future Dev" },
        "summary": "Plugin with future fields",
        "category": "workflows",
        "main": "future.lua",
        "futureField": "should be preserved",
        "anotherNewField": { "nested": true }
    }
    """

    static let invalidCategoryJSON = """
    {
        "id": "com.example.invalid",
        "name": "Invalid Category",
        "version": "1.0.0",
        "author": { "name": "Test" },
        "summary": "Has invalid category",
        "category": "not_a_real_category",
        "main": "init.lua"
    }
    """
}

// MARK: - PluginManifestTests

@Suite("PluginManifest Tests")
struct PluginManifestTests {
    @Test("Decodes valid manifest with all fields")
    func decodeValidManifest() throws {
        let data = try #require(PluginTestFixtures.validManifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        #expect(manifest.id == "com.example.test-plugin")
        #expect(manifest.name == "Test Plugin")
        #expect(manifest.version == "1.0.0")
        #expect(manifest.author.name == "Test Author")
        #expect(manifest.author.email == "test@example.com")
        #expect(manifest.summary == "A test plugin for unit testing")
        #expect(manifest.category == .healthChecks)
        #expect(manifest.main == "init.lua")
        #expect(manifest.capabilities?.count == 2)
        #expect(manifest.hooks?.count == 1)
        #expect(manifest.hooks?.first?.event == "PreToolUse")
        #expect(manifest.hooks?.first?.handler == "on_pre_tool")
    }

    @Test("Decodes minimal manifest")
    func decodeMinimalManifest() throws {
        let data = try #require(PluginTestFixtures.minimalManifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        #expect(manifest.id == "minimal.plugin")
        #expect(manifest.name == "Minimal")
        #expect(manifest.version == "0.1.0")
        #expect(manifest.author.name == "Someone")
        #expect(manifest.author.email == nil)
        #expect(manifest.category == .other)
        #expect(manifest.main == "main.lua")
        #expect(manifest.capabilities == nil)
        #expect(manifest.hooks == nil)
    }

    @Test("Preserves unknown fields during round-trip")
    func preserveUnknownFields() throws {
        let data = try #require(PluginTestFixtures.manifestWithUnknownFieldsJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        // Verify basic fields
        #expect(manifest.id == "com.example.future")
        #expect(manifest.category == .workflows)

        // Verify unknown fields are preserved
        #expect(manifest.additionalProperties?["futureField"]?.value as? String == "should be preserved")

        // Round-trip
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encoded = try encoder.encode(manifest)
        let redecoded = try JSONDecoder().decode(PluginManifest.self, from: encoded)

        #expect(redecoded.additionalProperties?["futureField"]?.value as? String == "should be preserved")
    }

    @Test("Decodes unknown category as other")
    func decodeUnknownCategory() throws {
        let data = try #require(PluginTestFixtures.invalidCategoryJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        // Unknown categories should decode as .other
        #expect(manifest.category == .other)
    }

    @Test("Manifest is Equatable")
    func manifestEquatable() throws {
        let data = try #require(PluginTestFixtures.minimalManifestJSON.data(using: .utf8))
        let manifest1 = try JSONDecoder().decode(PluginManifest.self, from: data)
        let manifest2 = try JSONDecoder().decode(PluginManifest.self, from: data)

        #expect(manifest1 == manifest2)
    }

    @Test("Manifest is Hashable")
    func manifestHashable() throws {
        let data = try #require(PluginTestFixtures.minimalManifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        var set = Set<PluginManifest>()
        set.insert(manifest)
        #expect(set.contains(manifest))
    }
}

// MARK: - PluginCapabilityTests

@Suite("PluginCapability Tests")
struct PluginCapabilityTests {
    @Test("Parses valid capability strings")
    func parseValidCapabilities() {
        let capabilities = PluginCapability.parse(capabilities: [
            "health:register",
            "config:read:global",
            "fs:exists",
        ])

        #expect(capabilities.contains(.healthRegister))
        #expect(capabilities.contains(.configReadGlobal))
        #expect(capabilities.contains(.fsExists))
        #expect(capabilities.count == 3)
    }

    @Test("Ignores unknown capability strings")
    func ignoreUnknownCapabilities() {
        let capabilities = PluginCapability.parse(capabilities: [
            "health:register",
            "unknown:capability",
            "another:invalid:one",
        ])

        #expect(capabilities.contains(.healthRegister))
        #expect(capabilities.count == 1)
    }

    @Test("Handles nil capabilities array")
    func handleNilCapabilities() {
        let capabilities = PluginCapability.parse(capabilities: nil)
        #expect(capabilities.isEmpty)
    }

    @Test("Handles empty capabilities array")
    func handleEmptyCapabilities() {
        let capabilities = PluginCapability.parse(capabilities: [])
        #expect(capabilities.isEmpty)
    }

    @Test("Identifies sensitive capabilities")
    func identifySensitiveCapabilities() {
        #expect(PluginCapability.configWriteProject.isSensitive == true)
        #expect(PluginCapability.configWriteLocal.isSensitive == true)
        #expect(PluginCapability.healthAutofix.isSensitive == true)
        #expect(PluginCapability.fsReadProject.isSensitive == true)

        #expect(PluginCapability.healthRegister.isSensitive == false)
        #expect(PluginCapability.configReadGlobal.isSensitive == false)
        #expect(PluginCapability.fsExists.isSensitive == false)
    }

    @Test("All capabilities have descriptions")
    func allCapabilitiesHaveDescriptions() {
        for capability in PluginCapability.allCases {
            #expect(!capability.localizedDescription.isEmpty)
            #expect(!capability.iconName.isEmpty)
        }
    }

    @Test("Capabilities are comparable")
    func capabilitiesComparable() {
        let sorted = [
            PluginCapability.fsExists,
            PluginCapability.configReadGlobal,
            PluginCapability.healthRegister,
        ].sorted()

        // Should be sorted by rawValue alphabetically
        #expect(sorted[0] == .configReadGlobal)
    }
}

// MARK: - PluginStateTests

@Suite("PluginState Tests")
struct PluginStateTests {
    @Test("LoadedPlugin has correct computed properties")
    func loadedPluginComputedProperties() throws {
        let manifestData = try #require(PluginTestFixtures.validManifestJSON.data(using: .utf8))
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)

        var plugin = LoadedPlugin(
            manifest: manifest,
            path: URL(fileURLWithPath: "/test/path"),
            state: .discovered,
            grantedCapabilities: [.healthRegister]
        )

        #expect(plugin.id == "com.example.test-plugin")
        #expect(plugin.isActive == false)
        #expect(!plugin
            .hasAllCapabilities) // Requested health:register and config:read:global, only granted health:register

        // Change state to active
        plugin.state = .active
        #expect(plugin.isActive == true)

        // Grant remaining capability
        plugin.grantedCapabilities.insert(.configReadGlobal)
        #expect(plugin.hasAllCapabilities)
        #expect(plugin.pendingCapabilities.isEmpty)
    }

    @Test("PluginLifecycleState encodes and decodes")
    func lifecycleStateRoundTrip() throws {
        for state in [
            PluginLifecycleState.discovered,
            .loading,
            .active,
            .error,
            .disabled,
            .unloading,
        ] {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(PluginLifecycleState.self, from: encoded)
            #expect(state == decoded)
        }
    }

    @Test("PluginHookResult stores execution data")
    func hookResultProperties() {
        let result = PluginHookResult(
            pluginId: "test.plugin",
            hookEvent: "PreToolUse",
            success: true,
            output: ["action": AnyCodable("allow")],
            duration: 0.05
        )

        #expect(result.pluginId == "test.plugin")
        #expect(result.hookEvent == "PreToolUse")
        #expect(result.success == true)
        #expect(result.output?["action"]?.value as? String == "allow")
        #expect(result.duration == 0.05)
        #expect(result.error == nil)
    }

    @Test("HookExecutionContext converts to dictionary")
    func hookContextToDictionary() {
        let context = HookExecutionContext(
            event: "PreToolUse",
            toolName: "Bash",
            toolInput: "npm test",
            projectPath: URL(fileURLWithPath: "/project"),
            additionalData: ["extra": AnyCodable("value")]
        )

        let dict = context.toDictionary()

        #expect(dict["event"] as? String == "PreToolUse")
        #expect(dict["toolName"] as? String == "Bash")
        #expect(dict["toolInput"] as? String == "npm test")
        #expect(dict["projectPath"] as? String == "/project")
        #expect(dict["extra"] as? String == "value")
        #expect(dict["toolOutput"] == nil) // Not set
    }
}

// MARK: - PluginInstallationStateTests

@Suite("PluginInstallationState Tests")
struct PluginInstallationStateTests {
    @Test("Installation state tracks disabled plugins")
    func disabledPluginTracking() {
        var state = PluginInstallationState()

        #expect(state.isDisabled("test.plugin") == false)

        state.disabledPlugins.insert("test.plugin")
        #expect(state.isDisabled("test.plugin") == true)

        state.disabledPlugins.remove("test.plugin")
        #expect(state.isDisabled("test.plugin") == false)
    }

    @Test("Installation state tracks granted capabilities")
    func grantedCapabilitiesTracking() {
        var state = PluginInstallationState()

        #expect(state.capabilities(for: "test.plugin").isEmpty)

        state.grantedCapabilities["test.plugin"] = ["health:register", "config:read:global"]
        let capabilities = state.capabilities(for: "test.plugin")

        #expect(capabilities.contains(.healthRegister))
        #expect(capabilities.contains(.configReadGlobal))
        #expect(capabilities.count == 2)
    }

    @Test("Installation state encodes and decodes")
    func installationStateRoundTrip() throws {
        var state = PluginInstallationState()
        state.disabledPlugins = ["disabled.plugin"]
        state.grantedCapabilities = ["test.plugin": ["health:register"]]
        state.plugins = [
            "test.plugin": InstalledPluginInfo(
                pluginId: "test.plugin",
                version: "1.0.0",
                installedAt: Date(),
                installPath: "test.plugin",
                source: .builtin
            ),
        ]

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PluginInstallationState.self, from: encoded)

        #expect(decoded.disabledPlugins.contains("disabled.plugin"))
        #expect(decoded.grantedCapabilities["test.plugin"]?.contains("health:register") == true)
        #expect(decoded.plugins["test.plugin"]?.version == "1.0.0")
    }
}

// MARK: - PluginErrorTests

@Suite("PluginError Tests")
struct PluginErrorTests {
    @Test("All errors have descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [PluginError] = [
            .pluginNotFound(id: "test"),
            .manifestMissing(path: "/path"),
            .manifestInvalid(path: "/path", reason: "bad json"),
            .loadFailed(id: "test", reason: "error"),
            .executionFailed(id: "test", function: "init", reason: "error"),
            .securityViolation(reason: "unsafe"),
            .functionNotFound(name: "missing"),
            .permissionDenied(capability: "write"),
            .timeout(id: "test", function: "slow"),
            .luaError(message: "syntax error"),
            .versionIncompatible(pluginId: "test", required: "2.0", current: "1.0"),
            .dependencyMissing(pluginId: "test", dependencyId: "dep"),
            .alreadyLoaded(id: "test"),
            .installFailed(reason: "network"),
            .uninstallFailed(id: "test", reason: "locked"),
            .checksumMismatch(expected: "abc", actual: "xyz"),
            .signatureInvalid(reason: "expired"),
            .networkError(reason: "timeout"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.recoverySuggestion != nil)
            #expect(error.failureReason != nil)
        }
    }

    @Test("Errors are equatable")
    func errorsEquatable() {
        let error1 = PluginError.pluginNotFound(id: "test")
        let error2 = PluginError.pluginNotFound(id: "test")
        let error3 = PluginError.pluginNotFound(id: "other")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
