import Foundation

/// Top-level Claude Code settings object.
///
/// This represents the structure of `settings.json` files (global or project-level).
///
/// Example JSON:
/// ```json
/// {
///   "permissions": {
///     "allow": ["Bash(npm run *)", "Read(src/**)"],
///     "deny": ["Read(.env)", "Bash(curl *)"]
///   },
///   "env": {
///     "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16384"
///   },
///   "hooks": {
///     "PreToolUse": [...],
///     "PostToolUse": [...]
///   },
///   "disallowedTools": ["..."],
///   "attribution": {
///     "commits": true,
///     "pullRequests": true
///   }
/// }
/// ```
public struct ClaudeSettings: Codable, Equatable, Hashable, Sendable {
    /// Permission rules for Claude Code operations.
    public var permissions: Permissions?

    /// Environment variables to set for Claude Code.
    public var env: [String: String]?

    /// Hook configurations keyed by event name (e.g., "PreToolUse", "PostToolUse").
    public var hooks: [String: [HookGroup]]?

    /// Array of tool names that are not allowed.
    public var disallowedTools: [String]?

    /// Attribution settings for commits and pull requests.
    public var attribution: Attribution?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public init(
        permissions: Permissions? = nil,
        env: [String: String]? = nil,
        hooks: [String: [HookGroup]]? = nil,
        disallowedTools: [String]? = nil,
        attribution: Attribution? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.permissions = permissions
        self.env = env
        self.hooks = hooks
        self.disallowedTools = disallowedTools
        self.attribution = attribution
        self.additionalProperties = additionalProperties
    }

    /// Returns hooks for the specified event.
    public func hooks(for event: String) -> [HookGroup]? {
        hooks?[event]
    }

    /// Checks if a specific tool is disallowed.
    public func isToolDisallowed(_ toolName: String) -> Bool {
        disallowedTools?.contains(toolName) ?? false
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case permissions
        case env
        case hooks
        case disallowedTools
        case attribution
    }

    private static let knownKeys: Set<String> = [
        "permissions", "env", "hooks", "disallowedTools", "attribution"
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        permissions = try container.decodeIfPresent(Permissions.self, forKey: .permissions)
        env = try container.decodeIfPresent([String: String].self, forKey: .env)
        hooks = try container.decodeIfPresent([String: [HookGroup]].self, forKey: .hooks)
        disallowedTools = try container.decodeIfPresent([String].self, forKey: .disallowedTools)
        attribution = try container.decodeIfPresent(Attribution.self, forKey: .attribution)

        // Capture unknown keys
        let allKeysContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var additional: [String: AnyCodable] = [:]

        for key in allKeysContainer.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                additional[key.stringValue] = try allKeysContainer.decode(AnyCodable.self, forKey: key)
            }
        }

        additionalProperties = additional.isEmpty ? nil : additional
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(permissions, forKey: .permissions)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(hooks, forKey: .hooks)
        try container.encodeIfPresent(disallowedTools, forKey: .disallowedTools)
        try container.encodeIfPresent(attribution, forKey: .attribution)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}
