import Foundation
import SwiftUI

// MARK: - Severity

/// Severity level for a health check finding.
enum Severity: Int, Comparable, CaseIterable, Sendable {
    /// Security risk that should be addressed immediately.
    case security = 0

    /// Potential issue that may cause problems.
    case warning = 1

    /// Suggestion for improvement.
    case suggestion = 2

    /// Good practice already in place.
    case good = 3

    // MARK: Internal

    var label: String {
        switch self {
        case .security:
            "Security"
        case .warning:
            "Warning"
        case .suggestion:
            "Suggestion"
        case .good:
            "Good"
        }
    }

    var icon: String {
        switch self {
        case .security:
            "exclamationmark.shield.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .suggestion:
            "lightbulb.fill"
        case .good:
            "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .security:
            .red
        case .warning:
            .yellow
        case .suggestion:
            .blue
        case .good:
            .green
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - AutoFix

/// Describes a fixable action for a health check finding.
///
/// Using an enum instead of closures to maintain `Sendable` conformance.
enum AutoFix: Sendable, Equatable {
    /// Add a pattern to the project's deny list.
    case addToDenyList(pattern: String)

    /// Create an empty `settings.local.json` file.
    case createLocalSettings

    // MARK: Internal

    var label: String {
        switch self {
        case let .addToDenyList(pattern):
            "Add \(pattern) to deny list"
        case .createLocalSettings:
            "Create settings.local.json"
        }
    }
}

// MARK: - Finding

/// A single finding from a health check.
struct Finding: Identifiable, Sendable {
    /// Unique identifier for this finding.
    let id: UUID

    /// Severity level of the finding.
    let severity: Severity

    /// Short title describing the finding.
    let title: String

    /// Detailed description with context.
    let description: String

    /// Optional auto-fix action for this finding.
    let autoFix: AutoFix?

    init(
        severity: Severity,
        title: String,
        description: String,
        autoFix: AutoFix? = nil
    ) {
        self.id = UUID()
        self.severity = severity
        self.title = title
        self.description = description
        self.autoFix = autoFix
    }
}

// MARK: - HealthCheckContext

/// All data needed by health checks to analyze a project's configuration.
struct HealthCheckContext: Sendable {
    /// Path to the project directory.
    let projectPath: URL

    /// Global settings from `~/.claude/settings.json`.
    let globalSettings: ClaudeSettings?

    /// Project shared settings from `.claude/settings.json`.
    let projectSettings: ClaudeSettings?

    /// Project local settings from `.claude/settings.local.json`.
    let projectLocalSettings: ClaudeSettings?

    /// MCP config from `.mcp.json`.
    let mcpConfig: MCPConfig?

    /// Global legacy config from `~/.claude.json`.
    let legacyConfig: LegacyConfig?

    /// Whether `settings.local.json` exists.
    let localSettingsExists: Bool

    /// Whether `.mcp.json` exists.
    let mcpConfigExists: Bool

    /// File size of `~/.claude.json` in bytes, if available.
    let globalConfigFileSize: Int64?

    /// All deny rules across all config sources.
    var allDenyRules: [String] {
        var rules: [String] = []
        if let deny = globalSettings?.permissions?.deny {
            rules.append(contentsOf: deny)
        }
        if let deny = projectSettings?.permissions?.deny {
            rules.append(contentsOf: deny)
        }
        if let deny = projectLocalSettings?.permissions?.deny {
            rules.append(contentsOf: deny)
        }
        return rules
    }

    /// All allow rules across all config sources.
    var allAllowRules: [String] {
        var rules: [String] = []
        if let allow = globalSettings?.permissions?.allow {
            rules.append(contentsOf: allow)
        }
        if let allow = projectSettings?.permissions?.allow {
            rules.append(contentsOf: allow)
        }
        if let allow = projectLocalSettings?.permissions?.allow {
            rules.append(contentsOf: allow)
        }
        return rules
    }

    /// All MCP servers from all sources.
    var allMCPServers: [(name: String, server: MCPServer)] {
        var servers: [(name: String, server: MCPServer)] = []
        if let mcpServers = mcpConfig?.mcpServers {
            for (name, server) in mcpServers {
                servers.append((name, server))
            }
        }
        if let globalServers = legacyConfig?.mcpServers {
            for (name, server) in globalServers {
                if !servers.contains(where: { $0.name == name }) {
                    servers.append((name, server))
                }
            }
        }
        return servers
    }
}
