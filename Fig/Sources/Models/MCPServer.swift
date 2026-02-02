import Foundation

/// Configuration for a Model Context Protocol (MCP) server.
///
/// MCP servers can be either stdio-based (using command/args) or HTTP-based (using url).
///
/// Stdio server example:
/// ```json
/// {
///   "command": "npx",
///   "args": ["-y", "@modelcontextprotocol/server-github"],
///   "env": { "GITHUB_TOKEN": "..." }
/// }
/// ```
///
/// HTTP server example:
/// ```json
/// {
///   "type": "http",
///   "url": "https://mcp.example.com/api",
///   "headers": { "Authorization": "Bearer ..." }
/// }
/// ```
public struct MCPServer: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        command: String? = nil,
        args: [String]? = nil,
        env: [String: String]? = nil,
        type: String? = nil,
        url: String? = nil,
        headers: [String: String]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.command = command
        self.args = args
        self.env = env
        self.type = type
        self.url = url
        self.headers = headers
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.args = try container.decodeIfPresent([String].self, forKey: .args)
        self.env = try container.decodeIfPresent([String: String].self, forKey: .env)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)

        // Capture unknown keys
        let allKeysContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var additional: [String: AnyCodable] = [:]

        for key in allKeysContainer.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                additional[key.stringValue] = try allKeysContainer.decode(AnyCodable.self, forKey: key)
            }
        }

        self.additionalProperties = additional.isEmpty ? nil : additional
    }

    // MARK: Public

    // MARK: - Stdio Server Properties

    /// The command to execute for stdio servers.
    public var command: String?

    /// Arguments to pass to the command.
    public var args: [String]?

    /// Environment variables for the server process.
    public var env: [String: String]?

    // MARK: - HTTP Server Properties

    /// Server type (e.g., "http" for HTTP servers, nil for stdio).
    public var type: String?

    /// URL for HTTP-based MCP servers.
    public var url: String?

    /// HTTP headers for authentication or other purposes.
    public var headers: [String: String]?

    // MARK: - Additional Properties

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    /// Whether this server uses stdio transport.
    public var isStdio: Bool {
        self.command != nil && self.type != "http"
    }

    /// Whether this server uses HTTP transport.
    public var isHTTP: Bool {
        self.type == "http" && self.url != nil
    }

    /// Creates a stdio-based MCP server configuration.
    public static func stdio(
        command: String,
        args: [String]? = nil,
        env: [String: String]? = nil
    ) -> MCPServer {
        MCPServer(command: command, args: args, env: env)
    }

    /// Creates an HTTP-based MCP server configuration.
    public static func http(
        url: String,
        headers: [String: String]? = nil
    ) -> MCPServer {
        MCPServer(type: "http", url: url, headers: headers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.command, forKey: .command)
        try container.encodeIfPresent(self.args, forKey: .args)
        try container.encodeIfPresent(self.env, forKey: .env)
        try container.encodeIfPresent(self.type, forKey: .type)
        try container.encodeIfPresent(self.url, forKey: .url)
        try container.encodeIfPresent(self.headers, forKey: .headers)

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
        case command
        case args
        case env
        case type
        case url
        case headers
    }

    private static let knownKeys: Set<String> = ["command", "args", "env", "type", "url", "headers"]
}
