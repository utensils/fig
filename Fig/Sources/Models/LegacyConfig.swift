import Foundation

/// Represents the structure of `~/.claude.json`, the global Claude Code configuration file.
///
/// This file contains user preferences, project history, and global MCP server configurations.
///
/// Example JSON:
/// ```json
/// {
///   "projects": {
///     "/path/to/project": {
///       "allowedTools": ["Bash", "Read"],
///       "hasTrustDialogAccepted": true
///     }
///   },
///   "customApiKeyResponses": { ... },
///   "preferences": { ... },
///   "mcpServers": { ... }
/// }
/// ```
public struct LegacyConfig: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        projects: [String: ProjectEntry]? = nil,
        customApiKeyResponses: [String: AnyCodable]? = nil,
        preferences: [String: AnyCodable]? = nil,
        mcpServers: [String: MCPServer]? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.projects = projects
        self.customApiKeyResponses = customApiKeyResponses
        self.preferences = preferences
        self.mcpServers = mcpServers
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.projects = try container.decodeIfPresent([String: ProjectEntry].self, forKey: .projects)
        self.customApiKeyResponses = try container.decodeIfPresent(
            [String: AnyCodable].self,
            forKey: .customApiKeyResponses
        )
        self.preferences = try container.decodeIfPresent([String: AnyCodable].self, forKey: .preferences)
        self.mcpServers = try container.decodeIfPresent([String: MCPServer].self, forKey: .mcpServers)

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

    /// Dictionary of projects keyed by their file path.
    public var projects: [String: ProjectEntry]?

    /// Custom API key responses stored by Claude Code.
    public var customApiKeyResponses: [String: AnyCodable]?

    /// User preferences.
    public var preferences: [String: AnyCodable]?

    /// Global MCP server configurations.
    public var mcpServers: [String: MCPServer]?

    /// Additional properties not explicitly modeled, preserved during round-trip.
    public var additionalProperties: [String: AnyCodable]?

    /// Returns all project paths.
    public var projectPaths: [String] {
        self.projects?.keys.sorted() ?? []
    }

    /// Returns all projects as an array with their paths set.
    public var allProjects: [ProjectEntry] {
        guard let projects else {
            return []
        }
        return projects.map { path, entry in
            var project = entry
            project.path = path
            return project
        }.sorted { ($0.path ?? "") < ($1.path ?? "") }
    }

    /// Returns all global MCP server names.
    public var globalServerNames: [String] {
        self.mcpServers?.keys.sorted() ?? []
    }

    /// Returns the project entry for the given path.
    public func project(at path: String) -> ProjectEntry? {
        self.projects?[path]
    }

    /// Returns the global MCP server configuration for the given name.
    public func globalServer(named name: String) -> MCPServer? {
        self.mcpServers?[name]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.projects, forKey: .projects)
        try container.encodeIfPresent(self.customApiKeyResponses, forKey: .customApiKeyResponses)
        try container.encodeIfPresent(self.preferences, forKey: .preferences)
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
        case projects
        case customApiKeyResponses
        case preferences
        case mcpServers
    }

    private static let knownKeys: Set<String> = [
        "projects", "customApiKeyResponses", "preferences", "mcpServers",
    ]
}
