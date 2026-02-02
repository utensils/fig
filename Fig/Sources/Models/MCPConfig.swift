import Foundation

/// Top-level configuration for MCP servers, typically stored in `.mcp.json`.
///
/// Example JSON:
/// ```json
/// {
///   "mcpServers": {
///     "github": {
///       "command": "npx",
///       "args": ["-y", "@modelcontextprotocol/server-github"],
///       "env": { "GITHUB_TOKEN": "..." }
///     },
///     "remote-api": {
///       "type": "http",
///       "url": "https://mcp.example.com/api",
///       "headers": { "Authorization": "Bearer ..." }
///     }
///   }
/// }
/// ```
public struct MCPConfig: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        mcpServers: [String: MCPServer]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.mcpServers = mcpServers
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mcpServers = try container.decodeIfPresent([String: MCPServer].self, forKey: .mcpServers)

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

    /// Dictionary of MCP server configurations keyed by server name.
    public var mcpServers: [String: MCPServer]?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    /// Returns an array of all server names.
    public var serverNames: [String] {
        mcpServers?.keys.sorted() ?? []
    }

    /// Returns the server configuration for the given name.
    public func server(named name: String) -> MCPServer? {
        mcpServers?[name]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mcpServers, forKey: .mcpServers)

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
        case mcpServers
    }

    private static let knownKeys: Set<String> = ["mcpServers"]
}
