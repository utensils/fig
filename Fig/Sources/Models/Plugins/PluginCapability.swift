import Foundation

// MARK: - PluginCapability

/// Capabilities that plugins can request.
///
/// The plugin system uses capability-based permissions rather than broad access grants.
/// Plugins must declare required capabilities in their manifest, and sensitive capabilities
/// require explicit user approval before the plugin can be loaded.
///
/// Capability strings follow a hierarchical format: `category:action:scope`
/// - `config:read:global` - Read global settings
/// - `health:register` - Register health checks
/// - `fs:read:project` - Read files in project directory
public enum PluginCapability: String, CaseIterable, Codable, Sendable {
    // MARK: - Configuration Access

    /// Read global settings (~/.claude/settings.json).
    case configReadGlobal = "config:read:global"

    /// Read project-level settings (.claude/settings.json).
    case configReadProject = "config:read:project"

    /// Read MCP server configurations.
    case configReadMCP = "config:read:mcp"

    /// Write to project settings (.claude/settings.json).
    case configWriteProject = "config:write:project"

    /// Write to local settings (.claude/settings.local.json).
    case configWriteLocal = "config:write:local"

    // MARK: - Health Check System

    /// Register new health checks.
    case healthRegister = "health:register"

    /// Create health check findings.
    case healthFindings = "health:findings"

    /// Provide auto-fix actions for findings.
    case healthAutofix = "health:autofix"

    // MARK: - Preset Contribution

    /// Register permission rule presets.
    case presetRegister = "preset:register"

    /// Register MCP server templates.
    case mcpTemplateRegister = "mcp:template:register"

    /// Register hook templates.
    case hookTemplateRegister = "hook:template:register"

    // MARK: - Event System

    /// Subscribe to lifecycle events.
    case eventSubscribe = "event:subscribe"

    // MARK: - User Interface

    /// Show notifications to the user.
    case uiNotification = "ui:notification"

    // MARK: - Filesystem (Sandboxed)

    /// Read files within the project directory.
    case fsReadProject = "fs:read:project"

    /// Check if files exist.
    case fsExists = "fs:exists"

    // MARK: Public

    /// Whether this capability is considered sensitive and requires explicit user approval.
    public var isSensitive: Bool {
        switch self {
        case .configWriteProject,
             .configWriteLocal,
             .healthAutofix,
             .fsReadProject:
            true
        default:
            false
        }
    }

    /// Human-readable description of what this capability allows.
    public var localizedDescription: String {
        switch self {
        case .configReadGlobal:
            "Read global Claude Code settings"
        case .configReadProject:
            "Read project-level settings"
        case .configReadMCP:
            "Read MCP server configurations"
        case .configWriteProject:
            "Modify project settings"
        case .configWriteLocal:
            "Modify local settings (not committed to git)"
        case .healthRegister:
            "Register custom health checks"
        case .healthFindings:
            "Report health check findings"
        case .healthAutofix:
            "Provide automatic fixes for issues"
        case .presetRegister:
            "Register permission presets"
        case .mcpTemplateRegister:
            "Register MCP server templates"
        case .hookTemplateRegister:
            "Register hook templates"
        case .eventSubscribe:
            "Listen to lifecycle events"
        case .uiNotification:
            "Show notifications"
        case .fsReadProject:
            "Read files in the project directory"
        case .fsExists:
            "Check if files exist"
        }
    }

    /// Icon name (SF Symbol) for this capability category.
    public var iconName: String {
        switch self {
        case .configReadGlobal,
             .configReadProject,
             .configReadMCP,
             .configWriteProject,
             .configWriteLocal:
            "gearshape"
        case .healthRegister,
             .healthFindings,
             .healthAutofix:
            "heart.text.square"
        case .presetRegister,
             .mcpTemplateRegister,
             .hookTemplateRegister:
            "square.grid.2x2"
        case .eventSubscribe:
            "bell"
        case .uiNotification:
            "bubble.left"
        case .fsReadProject,
             .fsExists:
            "folder"
        }
    }

    // MARK: Internal

    /// Parse a capability string into a PluginCapability.
    /// Returns nil if the string doesn't match a known capability.
    static func from(string: String) -> PluginCapability? {
        PluginCapability(rawValue: string)
    }

    /// Parse an array of capability strings, ignoring unknown capabilities.
    static func parse(capabilities: [String]?) -> Set<PluginCapability> {
        guard let capabilities else {
            return []
        }
        return Set(capabilities.compactMap { PluginCapability.from(string: $0) })
    }
}

// MARK: Comparable

extension PluginCapability: Comparable {
    public static func < (lhs: PluginCapability, rhs: PluginCapability) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
