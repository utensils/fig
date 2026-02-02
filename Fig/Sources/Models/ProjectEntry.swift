import Foundation

// MARK: - ProjectEntry

/// Represents a project discovered from LegacyConfig or filesystem scan.
///
/// Projects are directories that have been used with Claude Code,
/// typically tracked in `~/.claude.json`.
///
/// Example JSON (from projects dictionary):
/// ```json
/// {
///   "allowedTools": ["Bash", "Read", "Write"],
///   "hasTrustDialogAccepted": true,
///   "history": ["conversation-1", "conversation-2"],
///   "mcpServers": { ... }
/// }
/// ```
public struct ProjectEntry: Codable, Sendable, Identifiable {
    // MARK: Lifecycle

    public init(
        path: String? = nil,
        allowedTools: [String]? = nil,
        hasTrustDialogAccepted: Bool? = nil,
        history: [String]? = nil,
        mcpServers: [String: MCPServer]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.path = path
        self.allowedTools = allowedTools
        self.hasTrustDialogAccepted = hasTrustDialogAccepted
        self.history = history
        self.mcpServers = mcpServers
        self.additionalProperties = additionalProperties
        self.fallbackID = UUID().uuidString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decodeIfPresent(String.self, forKey: .path)
        self.allowedTools = try container.decodeIfPresent([String].self, forKey: .allowedTools)
        self.hasTrustDialogAccepted = try container.decodeIfPresent(Bool.self, forKey: .hasTrustDialogAccepted)
        self.history = try container.decodeIfPresent([String].self, forKey: .history)
        self.mcpServers = try container.decodeIfPresent([String: MCPServer].self, forKey: .mcpServers)
        self.fallbackID = UUID().uuidString

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

    /// The file path to the project directory.
    /// This is typically the dictionary key in LegacyConfig, stored here for convenience.
    public var path: String?

    /// List of tools that are allowed for this project.
    public var allowedTools: [String]?

    /// Whether the user has accepted the trust dialog for this project.
    public var hasTrustDialogAccepted: Bool?

    /// Conversation history identifiers.
    public var history: [String]?

    /// Project-specific MCP server configurations.
    public var mcpServers: [String: MCPServer]?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    public var id: String {
        self.path ?? self.fallbackID
    }

    /// The project name derived from the path.
    public var name: String? {
        guard let path else {
            return nil
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    /// Whether this project has any MCP servers configured.
    public var hasMCPServers: Bool {
        guard let servers = mcpServers else {
            return false
        }
        return !servers.isEmpty
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.path, forKey: .path)
        try container.encodeIfPresent(self.allowedTools, forKey: .allowedTools)
        try container.encodeIfPresent(self.hasTrustDialogAccepted, forKey: .hasTrustDialogAccepted)
        try container.encodeIfPresent(self.history, forKey: .history)
        try container.encodeIfPresent(self.mcpServers, forKey: .mcpServers)

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
        case path
        case allowedTools
        case hasTrustDialogAccepted
        case history
        case mcpServers
    }

    private static let knownKeys: Set<String> = [
        "path", "allowedTools", "hasTrustDialogAccepted", "history", "mcpServers",
    ]

    /// Fallback identifier used when `path` is nil, ensuring stable identity for SwiftUI.
    private let fallbackID: String
}

// MARK: Equatable

extension ProjectEntry: Equatable {
    public static func == (lhs: ProjectEntry, rhs: ProjectEntry) -> Bool {
        // Exclude fallbackID from equality comparison
        lhs.path == rhs.path &&
            lhs.allowedTools == rhs.allowedTools &&
            lhs.hasTrustDialogAccepted == rhs.hasTrustDialogAccepted &&
            lhs.history == rhs.history &&
            lhs.mcpServers == rhs.mcpServers &&
            lhs.additionalProperties == rhs.additionalProperties
    }
}

// MARK: Hashable

extension ProjectEntry: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Exclude fallbackID from hash computation
        hasher.combine(self.path)
        hasher.combine(self.allowedTools)
        hasher.combine(self.hasTrustDialogAccepted)
        hasher.combine(self.history)
        hasher.combine(self.mcpServers)
        hasher.combine(self.additionalProperties)
    }
}
