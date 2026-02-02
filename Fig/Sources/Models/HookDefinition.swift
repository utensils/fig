import Foundation

/// Defines a single hook that executes during Claude Code's tool lifecycle.
///
/// Hooks can run shell commands or other actions in response to tool events.
///
/// Example JSON:
/// ```json
/// {
///   "type": "command",
///   "command": "npm run lint"
/// }
/// ```
public struct HookDefinition: Codable, Equatable, Hashable, Sendable {
    /// The type of hook (e.g., "command").
    public var type: String?

    /// The command to execute when the hook fires.
    public var command: String?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public init(
        type: String? = nil,
        command: String? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.command = command
        self.additionalProperties = additionalProperties
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case command
    }

    private static let knownKeys: Set<String> = ["type", "command"]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)

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
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(command, forKey: .command)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}
