import Foundation

/// Represents Claude Code's permission configuration with allow/deny rule arrays.
///
/// Permissions control which tools and operations Claude Code can perform.
/// Rules use patterns like `"Bash(npm run *)"` or `"Read(src/**)"`.
///
/// Example JSON:
/// ```json
/// {
///   "allow": ["Bash(npm run *)", "Read(src/**)"],
///   "deny": ["Read(.env)", "Bash(curl *)"]
/// }
/// ```
public struct Permissions: Codable, Equatable, Hashable, Sendable {
    /// Array of allowed permission patterns.
    public var allow: [String]?

    /// Array of denied permission patterns.
    public var deny: [String]?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public init(
        allow: [String]? = nil,
        deny: [String]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.allow = allow
        self.deny = deny
        self.additionalProperties = additionalProperties
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case allow
        case deny
    }

    private static let knownKeys: Set<String> = ["allow", "deny"]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allow = try container.decodeIfPresent([String].self, forKey: .allow)
        deny = try container.decodeIfPresent([String].self, forKey: .deny)

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
        try container.encodeIfPresent(allow, forKey: .allow)
        try container.encodeIfPresent(deny, forKey: .deny)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}
