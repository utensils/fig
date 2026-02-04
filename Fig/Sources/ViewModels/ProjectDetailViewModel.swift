import AppKit
import Foundation
import OSLog

// MARK: - ProjectDetailTab

/// Tabs available in the project detail view.
enum ProjectDetailTab: String, CaseIterable, Identifiable, Sendable {
    case permissions
    case environment
    case mcpServers
    case hooks
    case claudeMD
    case effectiveConfig
    case healthCheck
    case advanced

    // MARK: Internal

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .permissions:
            "Permissions"
        case .environment:
            "Environment"
        case .mcpServers:
            "MCP Servers"
        case .hooks:
            "Hooks"
        case .claudeMD:
            "CLAUDE.md"
        case .effectiveConfig:
            "Effective Config"
        case .healthCheck:
            "Health"
        case .advanced:
            "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .permissions:
            "lock.shield"
        case .environment:
            "list.bullet.rectangle"
        case .mcpServers:
            "server.rack"
        case .hooks:
            "arrow.triangle.branch"
        case .claudeMD:
            "doc.text"
        case .effectiveConfig:
            "checkmark.rectangle.stack"
        case .healthCheck:
            "stethoscope"
        case .advanced:
            "gearshape.2"
        }
    }
}

// MARK: - ConfigFileStatus

/// Status of a configuration file.
struct ConfigFileStatus: Sendable {
    let exists: Bool
    let url: URL
}

// MARK: - ProjectDetailViewModel

/// View model for displaying project details.
@MainActor
@Observable
final class ProjectDetailViewModel {
    // MARK: Lifecycle

    init(projectPath: String, configManager: ConfigFileManager = .shared) {
        self.projectPath = projectPath
        self.projectURL = URL(fileURLWithPath: projectPath)
        self.configManager = configManager
    }

    // MARK: Internal

    /// The path to the project directory.
    let projectPath: String

    /// The URL to the project directory.
    let projectURL: URL

    /// The currently selected tab.
    var selectedTab: ProjectDetailTab = .permissions

    /// Whether data is currently loading.
    private(set) var isLoading = false

    /// The project entry from the global config.
    private(set) var projectEntry: ProjectEntry?

    /// The full global legacy config (~/.claude.json).
    private(set) var legacyConfig: LegacyConfig?

    /// Global settings.
    private(set) var globalSettings: ClaudeSettings?

    /// Project-level shared settings.
    private(set) var projectSettings: ClaudeSettings?

    /// Project-level local settings.
    private(set) var projectLocalSettings: ClaudeSettings?

    /// MCP configuration for the project.
    private(set) var mcpConfig: MCPConfig?

    /// Status of the project settings file.
    private(set) var projectSettingsStatus: ConfigFileStatus?

    /// Status of the project local settings file.
    private(set) var projectLocalSettingsStatus: ConfigFileStatus?

    /// Status of the MCP config file.
    private(set) var mcpConfigStatus: ConfigFileStatus?

    /// The fully merged settings with provenance tracking.
    private(set) var mergedSettings: MergedSettings?

    /// Environment variable overrides: keys that appear in multiple sources.
    /// Maps key -> array of (value, source) for all sources, ordered by precedence (lowest first).
    private(set) var envOverrides: [String: [(value: String, source: ConfigSource)]] = [:]

    /// The project name derived from the path.
    var projectName: String {
        self.projectURL.lastPathComponent
    }

    /// Whether the project directory exists.
    var projectExists: Bool {
        FileManager.default.fileExists(atPath: self.projectPath)
    }

    /// All permission rules with their sources.
    var allPermissions: [(rule: String, type: PermissionType, source: ConfigSource)] {
        var permissions: [(rule: String, type: PermissionType, source: ConfigSource)] = []

        // Global permissions
        if let global = globalSettings?.permissions {
            for rule in global.allow ?? [] {
                permissions.append((rule, .allow, .global))
            }
            for rule in global.deny ?? [] {
                permissions.append((rule, .deny, .global))
            }
        }

        // Project shared permissions
        if let shared = projectSettings?.permissions {
            for rule in shared.allow ?? [] {
                permissions.append((rule, .allow, .projectShared))
            }
            for rule in shared.deny ?? [] {
                permissions.append((rule, .deny, .projectShared))
            }
        }

        // Project local permissions
        if let local = projectLocalSettings?.permissions {
            for rule in local.allow ?? [] {
                permissions.append((rule, .allow, .projectLocal))
            }
            for rule in local.deny ?? [] {
                permissions.append((rule, .deny, .projectLocal))
            }
        }

        return permissions
    }

    /// All environment variables with their sources.
    var allEnvironmentVariables: [(key: String, value: String, source: ConfigSource)] {
        var envVars: [(key: String, value: String, source: ConfigSource)] = []

        // Global env vars
        if let global = globalSettings?.env {
            for (key, value) in global.sorted(by: { $0.key < $1.key }) {
                envVars.append((key, value, .global))
            }
        }

        // Project shared env vars
        if let shared = projectSettings?.env {
            for (key, value) in shared.sorted(by: { $0.key < $1.key }) {
                envVars.append((key, value, .projectShared))
            }
        }

        // Project local env vars
        if let local = projectLocalSettings?.env {
            for (key, value) in local.sorted(by: { $0.key < $1.key }) {
                envVars.append((key, value, .projectLocal))
            }
        }

        return envVars
    }

    /// All MCP servers with their sources.
    var allMCPServers: [(name: String, server: MCPServer, source: ConfigSource)] {
        var servers: [(name: String, server: MCPServer, source: ConfigSource)] = []

        // Project MCP config (.mcp.json)
        if let mcpServers = mcpConfig?.mcpServers {
            for (name, server) in mcpServers.sorted(by: { $0.key < $1.key }) {
                servers.append((name, server, .projectShared))
            }
        }

        // Project entry MCP servers (from ~/.claude.json)
        if let entryServers = projectEntry?.mcpServers {
            for (name, server) in entryServers.sorted(by: { $0.key < $1.key }) {
                // Avoid duplicates
                if !servers.contains(where: { $0.name == name }) {
                    servers.append((name, server, .global))
                }
            }
        }

        return servers
    }

    /// All disallowed tools with their sources.
    var allDisallowedTools: [(tool: String, source: ConfigSource)] {
        var tools: [(tool: String, source: ConfigSource)] = []

        if let global = globalSettings?.disallowedTools {
            for tool in global {
                tools.append((tool, .global))
            }
        }

        if let shared = projectSettings?.disallowedTools {
            for tool in shared {
                tools.append((tool, .projectShared))
            }
        }

        if let local = projectLocalSettings?.disallowedTools {
            for tool in local {
                tools.append((tool, .projectLocal))
            }
        }

        return tools
    }

    /// Attribution settings with their source.
    var attributionSettings: (attribution: Attribution, source: ConfigSource)? {
        // Local overrides shared, shared overrides global
        if let local = projectLocalSettings?.attribution {
            return (local, .projectLocal)
        }
        if let shared = projectSettings?.attribution {
            return (shared, .projectShared)
        }
        if let global = globalSettings?.attribution {
            return (global, .global)
        }
        return nil
    }

    /// Loads all configuration data for the project.
    func loadConfiguration() async {
        self.isLoading = true

        do {
            // Load global config to get project entry
            let globalConfig = try await configManager.readGlobalConfig()
            self.legacyConfig = globalConfig
            self.projectEntry = globalConfig?.project(at: self.projectPath)

            // Load global settings
            self.globalSettings = try await self.configManager.readGlobalSettings()

            // Load project settings
            self.projectSettings = try await self.configManager.readProjectSettings(for: self.projectURL)

            // Load project local settings
            self.projectLocalSettings = try await self.configManager.readProjectLocalSettings(for: self.projectURL)

            // Load MCP config
            self.mcpConfig = try await self.configManager.readMCPConfig(for: self.projectURL)

            // Update file statuses
            let settingsURL = await configManager.projectSettingsURL(for: self.projectURL)
            self.projectSettingsStatus = await ConfigFileStatus(
                exists: self.configManager.fileExists(at: settingsURL),
                url: settingsURL
            )

            let localSettingsURL = await configManager.projectLocalSettingsURL(for: self.projectURL)
            self.projectLocalSettingsStatus = await ConfigFileStatus(
                exists: self.configManager.fileExists(at: localSettingsURL),
                url: localSettingsURL
            )

            let mcpURL = await configManager.mcpConfigURL(for: self.projectURL)
            self.mcpConfigStatus = await ConfigFileStatus(
                exists: self.configManager.fileExists(at: mcpURL),
                url: mcpURL
            )

            // Compute merged settings
            let mergeService = SettingsMergeService(configManager: self.configManager)
            self.mergedSettings = await mergeService.mergeSettings(
                global: self.globalSettings,
                projectShared: self.projectSettings,
                projectLocal: self.projectLocalSettings
            )

            // Compute env var overrides (keys set in multiple sources)
            self.envOverrides = self.computeEnvOverrides()

            Log.general.info("Loaded configuration for project: \(self.projectName)")
        } catch {
            Log.general.error("Failed to load project configuration: \(error.localizedDescription)")
        }

        self.isLoading = false
    }

    /// Reveals the project in Finder.
    func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: self.projectPath)
    }

    /// Opens the project in Terminal.
    func openInTerminal() {
        let script = """
        tell application "Terminal"
            do script "cd \(projectPath.replacingOccurrences(of: "\"", with: "\\\""))"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                Log.general.error("Failed to open Terminal: \(error)")
            }
        }
    }

    // MARK: - MCP Server Management

    /// Deletes an MCP server by name and source.
    func deleteMCPServer(name: String, source: ConfigSource) async {
        do {
            switch source {
            case .projectShared:
                // Delete from .mcp.json
                guard var config = mcpConfig else { return }
                config.mcpServers?.removeValue(forKey: name)
                try await configManager.writeMCPConfig(config, for: projectURL)
                mcpConfig = config
                NotificationManager.shared.showSuccess("Server deleted", message: "'\(name)' removed from project")

            case .global:
                // Delete from ~/.claude.json
                guard var globalConfig = try await configManager.readGlobalConfig() else { return }
                globalConfig.mcpServers?.removeValue(forKey: name)
                try await configManager.writeGlobalConfig(globalConfig)
                // Also update projectEntry if it exists
                projectEntry = globalConfig.project(at: projectPath)
                NotificationManager.shared.showSuccess("Server deleted", message: "'\(name)' removed from global config")

            case .projectLocal:
                // Local settings don't typically have MCP servers, but handle gracefully
                Log.general.warning("Attempted to delete MCP server from local settings - not supported")
            }

            Log.general.info("Deleted MCP server '\(name)' from \(source.label)")
        } catch {
            Log.general.error("Failed to delete MCP server '\(name)': \(error)")
            NotificationManager.shared.showError(error)
        }
    }

    // MARK: Private

    private let configManager: ConfigFileManager

    /// Computes which env var keys have values in multiple sources (for override display).
    private func computeEnvOverrides() -> [String: [(value: String, source: ConfigSource)]] {
        var allValues: [String: [(value: String, source: ConfigSource)]] = [:]

        let sources: [(settings: ClaudeSettings?, source: ConfigSource)] = [
            (globalSettings, .global),
            (projectSettings, .projectShared),
            (projectLocalSettings, .projectLocal),
        ]

        for (settings, source) in sources {
            guard let env = settings?.env else { continue }
            for (key, value) in env {
                allValues[key, default: []].append((value, source))
            }
        }

        // Only keep keys that appear in more than one source
        return allValues.filter { $0.value.count > 1 }
    }
}

// MARK: - PermissionType

/// Type of permission rule.
enum PermissionType: String, Sendable {
    case allow
    case deny

    // MARK: Internal

    var icon: String {
        switch self {
        case .allow:
            "checkmark.circle.fill"
        case .deny:
            "xmark.circle.fill"
        }
    }
}
