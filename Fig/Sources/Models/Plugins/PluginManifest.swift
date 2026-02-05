import Foundation

// MARK: - PluginManifest

/// Metadata describing a Lua plugin and its capabilities.
///
/// Plugin manifests are stored in `plugin.json` at the root of each plugin directory.
/// The manifest defines the plugin's identity, entry point, hooks, and required permissions.
///
/// Example JSON:
/// ```json
/// {
///   "id": "com.example.my-plugin",
///   "name": "My Plugin",
///   "version": "1.0.0",
///   "author": { "name": "Author Name" },
///   "summary": "A brief description",
///   "main": "init.lua",
///   "category": "health-checks"
/// }
/// ```
public struct PluginManifest: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        version: String,
        author: PluginAuthor,
        summary: String,
        description: String? = nil,
        category: PluginCategory = .other,
        main: String = "init.lua",
        hooks: [PluginHookRegistration]? = nil,
        permissions: PluginPermissions? = nil,
        capabilities: [String]? = nil,
        minFigVersion: String? = nil,
        homepage: String? = nil,
        repository: String? = nil,
        license: String? = nil,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.summary = summary
        self.description = description
        self.category = category
        self.main = main
        self.hooks = hooks
        self.permissions = permissions
        self.capabilities = capabilities
        self.minFigVersion = minFigVersion
        self.homepage = homepage
        self.repository = repository
        self.license = license
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.version = try container.decode(String.self, forKey: .version)
        self.author = try container.decode(PluginAuthor.self, forKey: .author)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.category = try container.decodeIfPresent(PluginCategory.self, forKey: .category) ?? .other
        self.main = try container.decodeIfPresent(String.self, forKey: .main) ?? "init.lua"
        self.hooks = try container.decodeIfPresent([PluginHookRegistration].self, forKey: .hooks)
        self.permissions = try container.decodeIfPresent(PluginPermissions.self, forKey: .permissions)
        self.capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities)
        self.minFigVersion = try container.decodeIfPresent(String.self, forKey: .minFigVersion)
        self.homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        self.repository = try container.decodeIfPresent(String.self, forKey: .repository)
        self.license = try container.decodeIfPresent(String.self, forKey: .license)

        // Capture unknown keys
        let allKeysContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var additional: [String: AnyCodable] = [:]

        for key in allKeysContainer.allKeys where !Self.knownKeys.contains(key.stringValue) {
            additional[key.stringValue] = try allKeysContainer.decode(AnyCodable.self, forKey: key)
        }

        self.additionalProperties = additional.isEmpty ? nil : additional
    }

    // MARK: Public

    /// Unique plugin identifier (reverse-domain style, e.g., "com.author.plugin-name").
    public let id: String

    /// Human-readable plugin name.
    public let name: String

    /// Plugin version using semantic versioning (e.g., "1.2.3").
    public let version: String

    /// Plugin author information.
    public let author: PluginAuthor

    /// Short description of the plugin (max 140 characters recommended).
    public let summary: String

    /// Full description of the plugin (Markdown supported).
    public let description: String?

    /// Plugin category for marketplace organization.
    public let category: PluginCategory

    /// Main Lua entry point (relative to plugin directory).
    public let main: String

    /// Hooks this plugin wants to register for.
    public let hooks: [PluginHookRegistration]?

    /// Permissions the plugin requests (deprecated, use capabilities).
    public let permissions: PluginPermissions?

    /// Capabilities the plugin requests (e.g., "config:read", "health:register").
    public let capabilities: [String]?

    /// Minimum Fig version required.
    public let minFigVersion: String?

    /// Plugin homepage URL.
    public let homepage: String?

    /// Plugin source repository URL.
    public let repository: String?

    /// License identifier (SPDX format, e.g., "MIT").
    public let license: String?

    /// Additional properties for forward compatibility.
    public var additionalProperties: [String: AnyCodable]?

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.author, forKey: .author)
        try container.encode(self.summary, forKey: .summary)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encode(self.category, forKey: .category)
        try container.encode(self.main, forKey: .main)
        try container.encodeIfPresent(self.hooks, forKey: .hooks)
        try container.encodeIfPresent(self.permissions, forKey: .permissions)
        try container.encodeIfPresent(self.capabilities, forKey: .capabilities)
        try container.encodeIfPresent(self.minFigVersion, forKey: .minFigVersion)
        try container.encodeIfPresent(self.homepage, forKey: .homepage)
        try container.encodeIfPresent(self.repository, forKey: .repository)
        try container.encodeIfPresent(self.license, forKey: .license)

        // Encode additional properties
        if let additionalProperties {
            var additionalContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in additionalProperties {
                try additionalContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case author
        case summary
        case description
        case category
        case main
        case hooks
        case permissions
        case capabilities
        case minFigVersion
        case homepage
        case repository
        case license
    }

    private static let knownKeys: Set<String> = [
        "id", "name", "version", "author", "summary", "description",
        "category", "main", "hooks", "permissions", "capabilities",
        "minFigVersion", "homepage", "repository", "license",
    ]
}

// MARK: - PluginAuthor

/// Information about a plugin's author.
public struct PluginAuthor: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        name: String,
        email: String? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.email = email
        self.url = url
    }

    // MARK: Public

    /// Author's display name.
    public let name: String

    /// Author's email address (optional).
    public let email: String?

    /// Author's website URL (optional).
    public let url: String?
}

// MARK: - PluginCategory

/// Categories for organizing plugins in the marketplace.
public enum PluginCategory: String, CaseIterable, Sendable {
    case healthChecks = "health-checks"
    case permissions
    case mcpServers = "mcp-servers"
    case hooks
    case templates
    case workflows
    case integrations
    case other
}

// MARK: Codable

extension PluginCategory: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        // Fall back to .other for unknown categories (forward compatibility)
        self = PluginCategory(rawValue: rawValue) ?? .other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - PluginHookRegistration

/// A hook registration declared in the plugin manifest.
public struct PluginHookRegistration: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        event: String,
        handler: String,
        matcher: String? = nil,
        priority: Int? = nil
    ) {
        self.event = event
        self.handler = handler
        self.matcher = matcher
        self.priority = priority
    }

    // MARK: Public

    /// Hook event type (e.g., "PreToolUse", "PostToolUse").
    public let event: String

    /// Lua function name to call when the hook fires.
    public let handler: String

    /// Optional glob pattern to match against tool names (e.g., "Write(*.py)").
    public let matcher: String?

    /// Execution priority (lower values run first, default is 1000).
    public let priority: Int?
}

// MARK: - PluginPermissions

/// Legacy permissions structure (deprecated, use capabilities).
public struct PluginPermissions: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        fileRead: Bool? = nil,
        fileWrite: Bool? = nil,
        network: Bool? = nil,
        environment: Bool? = nil,
        shell: Bool? = nil
    ) {
        self.fileRead = fileRead
        self.fileWrite = fileWrite
        self.network = network
        self.environment = environment
        self.shell = shell
    }

    // MARK: Public

    /// Can read files (within sandbox).
    public let fileRead: Bool?

    /// Can write files (within sandbox).
    public let fileWrite: Bool?

    /// Can make HTTP requests.
    public let network: Bool?

    /// Can access environment variables.
    public let environment: Bool?

    /// Can execute shell commands (restricted).
    public let shell: Bool?
}
