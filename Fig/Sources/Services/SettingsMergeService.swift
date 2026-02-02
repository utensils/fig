import Foundation

// MARK: - SettingsMergeService

/// Service for merging Claude Code settings from multiple configuration levels.
///
/// Merge precedence (highest wins):
/// 1. Project local (`.claude/settings.local.json`)
/// 2. Project shared (`.claude/settings.json`)
/// 3. User global (`~/.claude/settings.json`)
///
/// Merge semantics:
/// - `permissions.allow` and `permissions.deny`: union of all arrays
/// - `env`: higher-precedence keys override lower
/// - `hooks`: merge by hook type, concatenate hook arrays
/// - `disallowedTools`: union of all arrays
/// - Scalar values (attribution, etc.): higher precedence wins
///
/// Example usage:
/// ```swift
/// let service = SettingsMergeService(configManager: ConfigFileManager.shared)
/// let merged = try await service.mergeSettings(for: projectURL)
/// print("Commit attribution: \(merged.attribution?.value.commits ?? false)")
/// print("Attribution source: \(merged.attribution?.source.displayName ?? "none")")
/// ```
actor SettingsMergeService {
    // MARK: Lifecycle

    init(configManager: ConfigFileManager = .shared) {
        self.configManager = configManager
    }

    // MARK: Internal

    /// Merges settings for a specific project from all configuration levels.
    ///
    /// - Parameter projectPath: The project directory path.
    /// - Returns: The merged settings with source tracking for each value.
    func mergeSettings(for projectPath: URL) async throws -> MergedSettings {
        // Load settings from all levels
        let global = try await configManager.readGlobalSettings()
        let projectShared = try await configManager.readProjectSettings(for: projectPath)
        let projectLocal = try await configManager.readProjectLocalSettings(for: projectPath)

        // Build source-value pairs for merging (order: lowest to highest precedence)
        let settingsWithSources: [(ClaudeSettings?, ConfigSource)] = [
            (global, .global),
            (projectShared, .projectShared),
            (projectLocal, .projectLocal),
        ]

        return merge(settingsWithSources)
    }

    /// Merges settings from pre-loaded settings objects.
    ///
    /// Useful for testing or when settings are already loaded.
    ///
    /// - Parameters:
    ///   - global: Global settings (lowest precedence).
    ///   - projectShared: Project shared settings.
    ///   - projectLocal: Project local settings (highest precedence).
    /// - Returns: The merged settings with source tracking.
    func mergeSettings(
        global: ClaudeSettings?,
        projectShared: ClaudeSettings?,
        projectLocal: ClaudeSettings?
    ) -> MergedSettings {
        let settingsWithSources: [(ClaudeSettings?, ConfigSource)] = [
            (global, .global),
            (projectShared, .projectShared),
            (projectLocal, .projectLocal),
        ]

        return merge(settingsWithSources)
    }

    // MARK: Private

    private let configManager: ConfigFileManager

    /// Core merge logic.
    private func merge(_ settingsWithSources: [(ClaudeSettings?, ConfigSource)]) -> MergedSettings {
        let permissions = mergePermissions(from: settingsWithSources)
        let env = mergeEnv(from: settingsWithSources)
        let hooks = mergeHooks(from: settingsWithSources)
        let disallowedTools = mergeDisallowedTools(from: settingsWithSources)
        let attribution = mergeAttribution(from: settingsWithSources)

        return MergedSettings(
            permissions: permissions,
            env: env,
            hooks: hooks,
            disallowedTools: disallowedTools,
            attribution: attribution
        )
    }

    /// Merges permissions by unioning allow and deny arrays.
    private func mergePermissions(
        from sources: [(ClaudeSettings?, ConfigSource)]
    ) -> MergedPermissions {
        var allowEntries: [MergedValue<String>] = []
        var denyEntries: [MergedValue<String>] = []
        var seenAllow = Set<String>()
        var seenDeny = Set<String>()

        for (settings, source) in sources {
            guard let permissions = settings?.permissions else {
                continue
            }

            // Union allow patterns (deduplicated)
            for pattern in permissions.allow ?? [] {
                if !seenAllow.contains(pattern) {
                    seenAllow.insert(pattern)
                    allowEntries.append(MergedValue(value: pattern, source: source))
                }
            }

            // Union deny patterns (deduplicated)
            for pattern in permissions.deny ?? [] {
                if !seenDeny.contains(pattern) {
                    seenDeny.insert(pattern)
                    denyEntries.append(MergedValue(value: pattern, source: source))
                }
            }
        }

        return MergedPermissions(allow: allowEntries, deny: denyEntries)
    }

    /// Merges environment variables with higher precedence overriding.
    private func mergeEnv(
        from sources: [(ClaudeSettings?, ConfigSource)]
    ) -> [String: MergedValue<String>] {
        var result: [String: MergedValue<String>] = [:]

        // Process in order (lowest to highest precedence)
        // Higher precedence overwrites lower
        for (settings, source) in sources {
            guard let env = settings?.env else {
                continue
            }

            for (key, value) in env {
                result[key] = MergedValue(value: value, source: source)
            }
        }

        return result
    }

    /// Merges hooks by event type, concatenating hook arrays.
    private func mergeHooks(
        from sources: [(ClaudeSettings?, ConfigSource)]
    ) -> MergedHooks {
        var result: [String: [MergedValue<HookGroup>]] = [:]

        // Process in order (lowest to highest precedence)
        // Concatenate arrays for each event type
        for (settings, source) in sources {
            guard let hooks = settings?.hooks else {
                continue
            }

            for (eventName, hookGroups) in hooks {
                var existing = result[eventName] ?? []
                for group in hookGroups {
                    existing.append(MergedValue(value: group, source: source))
                }
                result[eventName] = existing
            }
        }

        return MergedHooks(hooks: result)
    }

    /// Merges disallowed tools by unioning arrays.
    private func mergeDisallowedTools(
        from sources: [(ClaudeSettings?, ConfigSource)]
    ) -> [MergedValue<String>] {
        var result: [MergedValue<String>] = []
        var seen = Set<String>()

        for (settings, source) in sources {
            guard let tools = settings?.disallowedTools else {
                continue
            }

            for tool in tools {
                if !seen.contains(tool) {
                    seen.insert(tool)
                    result.append(MergedValue(value: tool, source: source))
                }
            }
        }

        return result
    }

    /// Merges attribution with higher precedence winning.
    private func mergeAttribution(
        from sources: [(ClaudeSettings?, ConfigSource)]
    ) -> MergedValue<Attribution>? {
        // Find the highest precedence source that has attribution
        // Process in reverse order (highest to lowest precedence)
        for (settings, source) in sources.reversed() {
            if let attribution = settings?.attribution {
                return MergedValue(value: attribution, source: source)
            }
        }

        return nil
    }
}
