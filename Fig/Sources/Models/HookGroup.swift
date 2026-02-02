import Foundation

/// Groups hook definitions with an optional matcher pattern.
///
/// Hook groups allow filtering which hooks apply based on patterns.
///
/// Example JSON:
/// ```json
/// {
///   "matcher": "Bash(*)",
///   "hooks": [
///     { "type": "command", "command": "npm run lint" }
///   ]
/// }
/// ```
public struct HookGroup: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        matcher: String? = nil,
        hooks: [HookDefinition]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.matcher = matcher
        self.hooks = hooks
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matcher = try container.decodeIfPresent(String.self, forKey: .matcher)
        hooks = try container.decodeIfPresent([HookDefinition].self, forKey: .hooks)

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

    // MARK: Public

    /// Optional pattern to match against tool names or operations.
    public var matcher: String?

    /// Array of hook definitions in this group.
    public var hooks: [HookDefinition]?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(matcher, forKey: .matcher)
        try container.encodeIfPresent(hooks, forKey: .hooks)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }

    // MARK: Private

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case matcher
        case hooks
    }

    private static let knownKeys: Set<String> = ["matcher", "hooks"]
}
