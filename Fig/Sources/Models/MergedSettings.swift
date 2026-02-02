import Foundation

// MARK: - MergedValue

/// Wraps a value with its source configuration file.
///
/// Used to track where each merged configuration value originated from.
///
/// Example:
/// ```swift
/// let attribution = MergedValue(
///     value: Attribution(commits: true),
///     source: .projectLocal
/// )
/// print(attribution.source.displayName) // "Local"
/// ```
public struct MergedValue<T: Sendable>: Sendable {
    /// The actual configuration value.
    public let value: T

    /// The source file where this value originated.
    public let source: ConfigSource

    public init(value: T, source: ConfigSource) {
        self.value = value
        self.source = source
    }
}

// MARK: Equatable

extension MergedValue: Equatable where T: Equatable {}

// MARK: Hashable

extension MergedValue: Hashable where T: Hashable {}

// MARK: - MergedPermissions

/// Represents merged permission rules with source tracking for each entry.
///
/// Permission arrays are unioned across all sources, with each entry
/// tracking which configuration file it came from.
public struct MergedPermissions: Sendable, Equatable, Hashable {
    /// Allowed permission patterns with their sources.
    public let allow: [MergedValue<String>]

    /// Denied permission patterns with their sources.
    public let deny: [MergedValue<String>]

    public init(
        allow: [MergedValue<String>] = [],
        deny: [MergedValue<String>] = []
    ) {
        self.allow = allow
        self.deny = deny
    }

    /// Returns all unique allow patterns (without source tracking).
    public var allowPatterns: [String] {
        allow.map(\.value)
    }

    /// Returns all unique deny patterns (without source tracking).
    public var denyPatterns: [String] {
        deny.map(\.value)
    }
}

// MARK: - MergedHooks

/// Represents merged hook configurations with source tracking.
///
/// Hooks are merged by event type, with hook arrays concatenated
/// from all sources (lower precedence first).
public struct MergedHooks: Sendable, Equatable, Hashable {
    /// Hook groups keyed by event name, with source tracking.
    public let hooks: [String: [MergedValue<HookGroup>]]

    public init(hooks: [String: [MergedValue<HookGroup>]] = [:]) {
        self.hooks = hooks
    }

    /// Returns hook groups for a specific event.
    public func groups(for event: String) -> [MergedValue<HookGroup>]? {
        hooks[event]
    }

    /// Returns all event names that have hooks configured.
    public var eventNames: [String] {
        hooks.keys.sorted()
    }
}

// MARK: - MergedSettings

/// The effective configuration for a project after merging all applicable settings files.
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
/// - Scalar values (attribution, etc.): higher precedence wins
public struct MergedSettings: Sendable, Equatable, Hashable {
    // MARK: Lifecycle

    public init(
        permissions: MergedPermissions = MergedPermissions(),
        env: [String: MergedValue<String>] = [:],
        hooks: MergedHooks = MergedHooks(),
        disallowedTools: [MergedValue<String>] = [],
        attribution: MergedValue<Attribution>? = nil
    ) {
        self.permissions = permissions
        self.env = env
        self.hooks = hooks
        self.disallowedTools = disallowedTools
        self.attribution = attribution
    }

    // MARK: Public

    /// Merged permission rules (unioned from all sources).
    public let permissions: MergedPermissions

    /// Merged environment variables (higher precedence overrides).
    public let env: [String: MergedValue<String>]

    /// Merged hook configurations (concatenated by event type).
    public let hooks: MergedHooks

    /// Merged disallowed tools (unioned from all sources).
    public let disallowedTools: [MergedValue<String>]

    /// Merged attribution settings (highest precedence wins).
    public let attribution: MergedValue<Attribution>?

    /// Returns the effective environment variables without source tracking.
    public var effectiveEnv: [String: String] {
        env.mapValues(\.value)
    }

    /// Returns the effective disallowed tools without source tracking.
    public var effectiveDisallowedTools: [String] {
        disallowedTools.map(\.value)
    }

    /// Checks if a specific tool is disallowed.
    public func isToolDisallowed(_ toolName: String) -> Bool {
        effectiveDisallowedTools.contains(toolName)
    }

    /// Returns the source for a specific environment variable.
    public func envSource(for key: String) -> ConfigSource? {
        env[key]?.source
    }
}
