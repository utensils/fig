@testable import Fig
import Foundation
import Testing

// MARK: - ConfigSourceTests

@Suite("ConfigSource Tests")
struct ConfigSourceTests {
    @Test("Has correct precedence order")
    func precedenceOrder() {
        #expect(ConfigSource.global.precedence == 0)
        #expect(ConfigSource.projectShared.precedence == 1)
        #expect(ConfigSource.projectLocal.precedence == 2)
    }

    @Test("Comparable implementation")
    func comparable() {
        #expect(ConfigSource.global < ConfigSource.projectShared)
        #expect(ConfigSource.projectShared < ConfigSource.projectLocal)
        #expect(ConfigSource.global < ConfigSource.projectLocal)
    }

    @Test("Display names are descriptive")
    func displayNames() {
        #expect(ConfigSource.global.displayName == "Global")
        #expect(ConfigSource.projectShared.displayName == "Project")
        #expect(ConfigSource.projectLocal.displayName == "Local")
    }

    @Test("File names are correct")
    func fileNames() {
        #expect(ConfigSource.global.fileName == "~/.claude/settings.json")
        #expect(ConfigSource.projectShared.fileName == ".claude/settings.json")
        #expect(ConfigSource.projectLocal.fileName == ".claude/settings.local.json")
    }

    @Test("CaseIterable provides all cases")
    func caseIterable() {
        let allCases = ConfigSource.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.global))
        #expect(allCases.contains(.projectShared))
        #expect(allCases.contains(.projectLocal))
    }
}

// MARK: - MergedValueTests

@Suite("MergedValue Tests")
struct MergedValueTests {
    @Test("Stores value and source")
    func storesValueAndSource() {
        let merged = MergedValue(value: "test-value", source: .projectLocal)

        #expect(merged.value == "test-value")
        #expect(merged.source == .projectLocal)
    }

    @Test("Equatable implementation")
    func equatable() {
        let merged1 = MergedValue(value: "test", source: .global)
        let merged2 = MergedValue(value: "test", source: .global)
        let merged3 = MergedValue(value: "test", source: .projectLocal)
        let merged4 = MergedValue(value: "different", source: .global)

        #expect(merged1 == merged2)
        #expect(merged1 != merged3)
        #expect(merged1 != merged4)
    }

    @Test("Hashable implementation")
    func hashable() {
        let merged = MergedValue(value: "test", source: .global)
        var set = Set<MergedValue<String>>()
        set.insert(merged)

        #expect(set.contains(merged))
    }
}

// MARK: - MergedPermissionsTests

@Suite("MergedPermissions Tests")
struct MergedPermissionsTests {
    @Test("Initializes with empty arrays by default")
    func defaultInitialization() {
        let permissions = MergedPermissions()

        #expect(permissions.allow.isEmpty)
        #expect(permissions.deny.isEmpty)
    }

    @Test("Provides allow patterns")
    func allowPatterns() {
        let permissions = MergedPermissions(
            allow: [
                MergedValue(value: "Bash(*)", source: .global),
                MergedValue(value: "Read(src/**)", source: .projectShared),
            ]
        )

        #expect(permissions.allowPatterns == ["Bash(*)", "Read(src/**)"])
    }

    @Test("Provides deny patterns")
    func denyPatterns() {
        let permissions = MergedPermissions(
            deny: [
                MergedValue(value: "Read(.env)", source: .global),
                MergedValue(value: "Bash(rm *)", source: .projectLocal),
            ]
        )

        #expect(permissions.denyPatterns == ["Read(.env)", "Bash(rm *)"])
    }
}

// MARK: - MergedHooksTests

@Suite("MergedHooks Tests")
struct MergedHooksTests {
    @Test("Returns event names")
    func eventNames() {
        let hook1 = HookGroup(matcher: "Bash(*)", hooks: [])
        let hook2 = HookGroup(matcher: "Read(*)", hooks: [])

        let mergedHooks = MergedHooks(hooks: [
            "PreToolUse": [MergedValue(value: hook1, source: .global)],
            "PostToolUse": [MergedValue(value: hook2, source: .projectShared)],
        ])

        let names = mergedHooks.eventNames
        #expect(names.contains("PreToolUse"))
        #expect(names.contains("PostToolUse"))
    }

    @Test("Returns groups for event")
    func groupsForEvent() {
        let hook = HookGroup(matcher: "Bash(*)", hooks: [])
        let mergedHooks = MergedHooks(hooks: [
            "PreToolUse": [MergedValue(value: hook, source: .global)],
        ])

        let groups = mergedHooks.groups(for: "PreToolUse")
        #expect(groups?.count == 1)
        #expect(mergedHooks.groups(for: "NonExistent") == nil)
    }
}

// MARK: - MergedSettingsTests

@Suite("MergedSettings Tests")
struct MergedSettingsTests {
    @Test("Returns effective environment variables")
    func effectiveEnv() {
        let settings = MergedSettings(
            env: [
                "DEBUG": MergedValue(value: "true", source: .projectLocal),
                "API_URL": MergedValue(value: "https://api.example.com", source: .global),
            ]
        )

        let env = settings.effectiveEnv
        #expect(env["DEBUG"] == "true")
        #expect(env["API_URL"] == "https://api.example.com")
    }

    @Test("Returns effective disallowed tools")
    func effectiveDisallowedTools() {
        let settings = MergedSettings(
            disallowedTools: [
                MergedValue(value: "DangerousTool", source: .global),
                MergedValue(value: "AnotherTool", source: .projectShared),
            ]
        )

        #expect(settings.effectiveDisallowedTools == ["DangerousTool", "AnotherTool"])
    }

    @Test("Checks if tool is disallowed")
    func isToolDisallowed() {
        let settings = MergedSettings(
            disallowedTools: [
                MergedValue(value: "DangerousTool", source: .global),
            ]
        )

        #expect(settings.isToolDisallowed("DangerousTool") == true)
        #expect(settings.isToolDisallowed("SafeTool") == false)
    }

    @Test("Returns env source")
    func envSource() {
        let settings = MergedSettings(
            env: [
                "DEBUG": MergedValue(value: "true", source: .projectLocal),
            ]
        )

        #expect(settings.envSource(for: "DEBUG") == .projectLocal)
        #expect(settings.envSource(for: "MISSING") == nil)
    }
}

// MARK: - SettingsMergeServiceTests

@Suite("SettingsMergeService Tests")
struct SettingsMergeServiceTests {
    @Suite("Permission Merging Tests")
    struct PermissionMergingTests {
        @Test("Unions allow patterns from all sources")
        func unionsAllowPatterns() async {
            let global = ClaudeSettings(
                permissions: Permissions(allow: ["Bash(npm run *)"])
            )
            let projectShared = ClaudeSettings(
                permissions: Permissions(allow: ["Read(src/**)"])
            )
            let projectLocal = ClaudeSettings(
                permissions: Permissions(allow: ["Write(docs/**)"]))

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: projectLocal
            )

            let patterns = merged.permissions.allowPatterns
            #expect(patterns.contains("Bash(npm run *)"))
            #expect(patterns.contains("Read(src/**)"))
            #expect(patterns.contains("Write(docs/**)"))
        }

        @Test("Unions deny patterns from all sources")
        func unionsDenyPatterns() async {
            let global = ClaudeSettings(
                permissions: Permissions(deny: ["Read(.env)"])
            )
            let projectShared = ClaudeSettings(
                permissions: Permissions(deny: ["Bash(curl *)"])
            )

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: nil
            )

            let patterns = merged.permissions.denyPatterns
            #expect(patterns.contains("Read(.env)"))
            #expect(patterns.contains("Bash(curl *)"))
        }

        @Test("Deduplicates permission patterns")
        func deduplicatesPatterns() async {
            let global = ClaudeSettings(
                permissions: Permissions(allow: ["Bash(*)"])
            )
            let projectShared = ClaudeSettings(
                permissions: Permissions(allow: ["Bash(*)", "Read(*)"])
            )

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: nil
            )

            let patterns = merged.permissions.allowPatterns
            #expect(patterns.count == 2)
            #expect(patterns.filter { $0 == "Bash(*)" }.count == 1)
        }

        @Test("Tracks source for each permission")
        func tracksPermissionSource() async {
            let global = ClaudeSettings(
                permissions: Permissions(allow: ["Bash(*)"])
            )
            let projectLocal = ClaudeSettings(
                permissions: Permissions(allow: ["Read(*)"])
            )

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            let bashEntry = merged.permissions.allow.first { $0.value == "Bash(*)" }
            let readEntry = merged.permissions.allow.first { $0.value == "Read(*)" }

            #expect(bashEntry?.source == .global)
            #expect(readEntry?.source == .projectLocal)
        }
    }

    @Suite("Environment Variable Merging Tests")
    struct EnvMergingTests {
        @Test("Higher precedence overrides lower")
        func higherPrecedenceOverrides() async {
            let global = ClaudeSettings(env: ["DEBUG": "false", "LOG_LEVEL": "info"])
            let projectLocal = ClaudeSettings(env: ["DEBUG": "true"])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            #expect(merged.effectiveEnv["DEBUG"] == "true")
            #expect(merged.effectiveEnv["LOG_LEVEL"] == "info")
            #expect(merged.envSource(for: "DEBUG") == .projectLocal)
            #expect(merged.envSource(for: "LOG_LEVEL") == .global)
        }

        @Test("Preserves all unique keys")
        func preservesUniqueKeys() async {
            let global = ClaudeSettings(env: ["GLOBAL_VAR": "global"])
            let projectShared = ClaudeSettings(env: ["SHARED_VAR": "shared"])
            let projectLocal = ClaudeSettings(env: ["LOCAL_VAR": "local"])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: projectLocal
            )

            #expect(merged.effectiveEnv.count == 3)
            #expect(merged.effectiveEnv["GLOBAL_VAR"] == "global")
            #expect(merged.effectiveEnv["SHARED_VAR"] == "shared")
            #expect(merged.effectiveEnv["LOCAL_VAR"] == "local")
        }
    }

    @Suite("Hook Merging Tests")
    struct HookMergingTests {
        @Test("Concatenates hooks by event type")
        func concatenatesHooks() async {
            let globalHook = HookGroup(
                matcher: "Bash(*)",
                hooks: [HookDefinition(type: "command", command: "echo global")]
            )
            let localHook = HookGroup(
                matcher: "Read(*)",
                hooks: [HookDefinition(type: "command", command: "echo local")]
            )

            let global = ClaudeSettings(hooks: ["PreToolUse": [globalHook]])
            let projectLocal = ClaudeSettings(hooks: ["PreToolUse": [localHook]])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            let preToolUseHooks = merged.hooks.groups(for: "PreToolUse")
            #expect(preToolUseHooks?.count == 2)

            let sources = preToolUseHooks?.map(\.source)
            #expect(sources?.contains(.global) == true)
            #expect(sources?.contains(.projectLocal) == true)
        }

        @Test("Preserves hooks for different events")
        func preservesDifferentEvents() async {
            let preHook = HookGroup(hooks: [HookDefinition(type: "command", command: "pre")])
            let postHook = HookGroup(hooks: [HookDefinition(type: "command", command: "post")])

            let global = ClaudeSettings(hooks: [
                "PreToolUse": [preHook],
                "PostToolUse": [postHook],
            ])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: nil
            )

            #expect(merged.hooks.eventNames.count == 2)
            #expect(merged.hooks.groups(for: "PreToolUse") != nil)
            #expect(merged.hooks.groups(for: "PostToolUse") != nil)
        }
    }

    @Suite("Disallowed Tools Merging Tests")
    struct DisallowedToolsMergingTests {
        @Test("Unions disallowed tools")
        func unionsDisallowedTools() async {
            let global = ClaudeSettings(disallowedTools: ["Tool1"])
            let projectShared = ClaudeSettings(disallowedTools: ["Tool2"])
            let projectLocal = ClaudeSettings(disallowedTools: ["Tool3"])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: projectLocal
            )

            #expect(merged.effectiveDisallowedTools.count == 3)
            #expect(merged.isToolDisallowed("Tool1"))
            #expect(merged.isToolDisallowed("Tool2"))
            #expect(merged.isToolDisallowed("Tool3"))
        }

        @Test("Deduplicates disallowed tools")
        func deduplicatesDisallowedTools() async {
            let global = ClaudeSettings(disallowedTools: ["Tool1"])
            let projectLocal = ClaudeSettings(disallowedTools: ["Tool1", "Tool2"])

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            #expect(merged.effectiveDisallowedTools.count == 2)
        }
    }

    @Suite("Attribution Merging Tests")
    struct AttributionMergingTests {
        @Test("Higher precedence wins for scalar values")
        func higherPrecedenceWins() async {
            let global = ClaudeSettings(attribution: Attribution(commits: false, pullRequests: false))
            let projectLocal = ClaudeSettings(attribution: Attribution(commits: true, pullRequests: true))

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            #expect(merged.attribution?.value.commits == true)
            #expect(merged.attribution?.value.pullRequests == true)
            #expect(merged.attribution?.source == .projectLocal)
        }

        @Test("Falls back to lower precedence when higher is nil")
        func fallsBackToLowerPrecedence() async {
            let global = ClaudeSettings(attribution: Attribution(commits: true))

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: nil
            )

            #expect(merged.attribution?.value.commits == true)
            #expect(merged.attribution?.source == .global)
        }

        @Test("Returns nil when no source has attribution")
        func returnsNilWhenNoAttribution() async {
            let global = ClaudeSettings()
            let projectLocal = ClaudeSettings()

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: nil,
                projectLocal: projectLocal
            )

            #expect(merged.attribution == nil)
        }
    }

    @Suite("Empty Settings Tests")
    struct EmptySettingsTests {
        @Test("Handles all nil settings")
        func handlesAllNil() async {
            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: nil,
                projectShared: nil,
                projectLocal: nil
            )

            #expect(merged.permissions.allow.isEmpty)
            #expect(merged.permissions.deny.isEmpty)
            #expect(merged.env.isEmpty)
            #expect(merged.hooks.eventNames.isEmpty)
            #expect(merged.disallowedTools.isEmpty)
            #expect(merged.attribution == nil)
        }

        @Test("Handles empty settings objects")
        func handlesEmptySettings() async {
            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: ClaudeSettings(),
                projectShared: ClaudeSettings(),
                projectLocal: ClaudeSettings()
            )

            #expect(merged.permissions.allow.isEmpty)
            #expect(merged.env.isEmpty)
        }
    }

    @Suite("Integration Tests")
    struct IntegrationTests {
        @Test("Complex merge scenario")
        func complexMerge() async {
            let global = ClaudeSettings(
                permissions: Permissions(
                    allow: ["Bash(npm run *)"],
                    deny: ["Read(.env)"]
                ),
                env: ["LOG_LEVEL": "info", "DEBUG": "false"],
                disallowedTools: ["DangerousTool"],
                attribution: Attribution(commits: false)
            )

            let projectShared = ClaudeSettings(
                permissions: Permissions(
                    allow: ["Read(src/**)"]
                ),
                env: ["API_URL": "https://api.example.com"]
            )

            let projectLocal = ClaudeSettings(
                permissions: Permissions(
                    deny: ["Bash(rm *)"]
                ),
                env: ["DEBUG": "true"],
                attribution: Attribution(commits: true, pullRequests: true)
            )

            let service = SettingsMergeService()
            let merged = await service.mergeSettings(
                global: global,
                projectShared: projectShared,
                projectLocal: projectLocal
            )

            // Permissions are unioned
            #expect(merged.permissions.allowPatterns.count == 2)
            #expect(merged.permissions.denyPatterns.count == 2)

            // Env vars: DEBUG overridden by projectLocal
            #expect(merged.effectiveEnv["DEBUG"] == "true")
            #expect(merged.envSource(for: "DEBUG") == .projectLocal)
            #expect(merged.effectiveEnv["LOG_LEVEL"] == "info")
            #expect(merged.effectiveEnv["API_URL"] == "https://api.example.com")

            // Disallowed tools unioned
            #expect(merged.isToolDisallowed("DangerousTool"))

            // Attribution from highest precedence
            #expect(merged.attribution?.value.commits == true)
            #expect(merged.attribution?.source == .projectLocal)
        }
    }
}
