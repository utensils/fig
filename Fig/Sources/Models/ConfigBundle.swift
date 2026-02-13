import Foundation

// MARK: - ConfigBundle

/// A bundle containing exported project configuration.
///
/// This format allows exporting and importing complete project configurations,
/// including settings, local settings, and MCP servers.
///
/// Example JSON:
/// ```json
/// {
///   "version": 1,
///   "exportedAt": "2024-01-15T10:30:00Z",
///   "projectName": "my-project",
///   "settings": { ... },
///   "localSettings": { ... },
///   "mcpServers": { ... }
/// }
/// ```
struct ConfigBundle: Codable, Equatable {
    // MARK: Lifecycle

    init(
        version: Int = Self.currentVersion,
        exportedAt: Date = Date(),
        projectName: String,
        settings: ClaudeSettings? = nil,
        localSettings: ClaudeSettings? = nil,
        mcpServers: MCPConfig? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.projectName = projectName
        self.settings = settings
        self.localSettings = localSettings
        self.mcpServers = mcpServers
    }

    // MARK: Internal

    /// Current bundle format version.
    static let currentVersion = 1

    /// File extension for config bundles.
    static let fileExtension = "claudeconfig"

    /// Bundle format version.
    let version: Int

    /// When the bundle was exported.
    let exportedAt: Date

    /// Name of the project this bundle was exported from.
    let projectName: String

    /// Project settings (settings.json).
    var settings: ClaudeSettings?

    /// Local project settings (settings.local.json).
    var localSettings: ClaudeSettings?

    /// MCP server configurations (.mcp.json).
    var mcpServers: MCPConfig?

    /// Whether the bundle has any content.
    var isEmpty: Bool {
        self.settings == nil && self.localSettings == nil && self.mcpServers == nil
    }

    /// Whether the bundle contains potentially sensitive data.
    var containsSensitiveData: Bool {
        // Check local settings (usually contains sensitive data)
        if self.localSettings != nil {
            return true
        }

        // Check for env vars in MCP servers
        if let servers = mcpServers?.mcpServers {
            for server in servers.values {
                if let env = server.env, !env.isEmpty {
                    return true
                }
            }
        }

        return false
    }

    /// Summary of bundle contents.
    var contentSummary: [String] {
        var summary: [String] = []

        if let settings {
            var items: [String] = []
            if let permissions = settings.permissions {
                let allowCount = permissions.allow?.count ?? 0
                let denyCount = permissions.deny?.count ?? 0
                if allowCount > 0 || denyCount > 0 {
                    items.append("\(allowCount) allow, \(denyCount) deny rules")
                }
            }
            if let env = settings.env, !env.isEmpty {
                items.append("\(env.count) env vars")
            }
            if settings.hooks != nil {
                items.append("hooks")
            }
            if !items.isEmpty {
                summary.append("Settings: \(items.joined(separator: ", "))")
            } else {
                summary.append("Settings (empty)")
            }
        }

        if let localSettings {
            var items: [String] = []
            if let permissions = localSettings.permissions {
                let allowCount = permissions.allow?.count ?? 0
                let denyCount = permissions.deny?.count ?? 0
                if allowCount > 0 || denyCount > 0 {
                    items.append("\(allowCount) allow, \(denyCount) deny rules")
                }
            }
            if let env = localSettings.env, !env.isEmpty {
                items.append("\(env.count) env vars")
            }
            if localSettings.hooks != nil {
                items.append("hooks")
            }
            if !items.isEmpty {
                summary.append("Local Settings: \(items.joined(separator: ", "))")
            } else {
                summary.append("Local Settings (empty)")
            }
        }

        if let mcpServers = mcpServers?.mcpServers, !mcpServers.isEmpty {
            summary.append("MCP Servers: \(mcpServers.count)")
        }

        return summary
    }
}

// MARK: - ConfigBundleComponent

/// Components that can be included in a config bundle.
enum ConfigBundleComponent: String, CaseIterable, Identifiable {
    case settings
    case localSettings
    case mcpServers

    // MARK: Internal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .settings: "Settings (settings.json)"
        case .localSettings: "Local Settings (settings.local.json)"
        case .mcpServers: "MCP Servers (.mcp.json)"
        }
    }

    var icon: String {
        switch self {
        case .settings: "gearshape"
        case .localSettings: "gearshape.2"
        case .mcpServers: "server.rack"
        }
    }

    var isSensitive: Bool {
        self == .localSettings
    }

    var sensitiveWarning: String? {
        switch self {
        case .localSettings:
            "May contain API keys, tokens, or other sensitive data"
        case .mcpServers:
            "May contain environment variables with sensitive data"
        default:
            nil
        }
    }
}

// MARK: - ImportConflict

/// Represents a conflict found during import.
struct ImportConflict: Identifiable {
    enum ImportResolution: String, CaseIterable, Identifiable {
        case merge // Combine with existing (for arrays/dicts)
        case replace // Replace existing completely
        case skip // Keep existing, skip import

        // MARK: Internal

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .merge: "Merge with existing"
            case .replace: "Replace existing"
            case .skip: "Skip (keep existing)"
            }
        }
    }

    let id = UUID()
    let component: ConfigBundleComponent
    let description: String
    var resolution: ImportResolution = .merge
}

// MARK: - ImportResult

/// Result of an import operation.
struct ImportResult {
    let success: Bool
    let message: String
    let componentsImported: [ConfigBundleComponent]
    let componentsSkipped: [ConfigBundleComponent]
    let errors: [String]
}
