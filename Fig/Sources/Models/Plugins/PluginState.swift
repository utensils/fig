import Foundation

// MARK: - PluginLifecycleState

/// Lifecycle state of a plugin.
public enum PluginLifecycleState: String, Codable, Sendable {
    /// Plugin has been discovered but not loaded.
    case discovered

    /// Plugin is currently being loaded.
    case loading

    /// Plugin has been loaded and initialized successfully.
    case active

    /// Plugin encountered an error during loading or execution.
    case error

    /// Plugin has been disabled by the user.
    case disabled

    /// Plugin is being unloaded.
    case unloading
}

// MARK: - LoadedPlugin

/// Runtime representation of a loaded plugin.
public struct LoadedPlugin: Sendable, Identifiable {
    // MARK: Lifecycle

    public init(
        manifest: PluginManifest,
        path: URL,
        state: PluginLifecycleState = .discovered,
        error: PluginError? = nil,
        config: [String: AnyCodable] = [:],
        loadedAt: Date? = nil,
        grantedCapabilities: Set<PluginCapability> = []
    ) {
        self.manifest = manifest
        self.path = path
        self.state = state
        self.error = error
        self.config = config
        self.loadedAt = loadedAt
        self.grantedCapabilities = grantedCapabilities
    }

    // MARK: Public

    /// The plugin's manifest.
    public let manifest: PluginManifest

    /// Path to the plugin directory.
    public let path: URL

    /// Current lifecycle state.
    public var state: PluginLifecycleState

    /// Error if the plugin is in error state.
    public var error: PluginError?

    /// Plugin-specific configuration values.
    public var config: [String: AnyCodable]

    /// When the plugin was last loaded.
    public var loadedAt: Date?

    /// Capabilities that have been granted to this plugin.
    public var grantedCapabilities: Set<PluginCapability>

    public var id: String {
        self.manifest.id
    }

    /// Whether the plugin is currently active and can execute.
    public var isActive: Bool {
        self.state == .active
    }

    /// Capabilities requested by the plugin that haven't been granted.
    public var pendingCapabilities: Set<PluginCapability> {
        let requested = PluginCapability.parse(capabilities: self.manifest.capabilities)
        return requested.subtracting(self.grantedCapabilities)
    }

    /// Whether the plugin has all requested capabilities.
    public var hasAllCapabilities: Bool {
        self.pendingCapabilities.isEmpty
    }
}

// MARK: - PluginInstallationState

/// Persistent state tracking all installed plugins.
public struct PluginInstallationState: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        version: Int = Self.currentVersion,
        plugins: [String: InstalledPluginInfo] = [:],
        disabledPlugins: Set<String> = [],
        grantedCapabilities: [String: Set<String>] = [:]
    ) {
        self.version = version
        self.plugins = plugins
        self.disabledPlugins = disabledPlugins
        self.grantedCapabilities = grantedCapabilities
    }

    // MARK: Public

    /// Current state file format version.
    public static let currentVersion = 1

    /// State file format version.
    public let version: Int

    /// Installed plugins keyed by plugin ID.
    public var plugins: [String: InstalledPluginInfo]

    /// Plugin IDs that have been disabled by the user.
    public var disabledPlugins: Set<String>

    /// Capabilities granted to each plugin, keyed by plugin ID.
    /// Values are raw capability strings for forward compatibility.
    public var grantedCapabilities: [String: Set<String>]

    /// Check if a plugin is disabled.
    public func isDisabled(_ pluginId: String) -> Bool {
        self.disabledPlugins.contains(pluginId)
    }

    /// Get granted capabilities for a plugin.
    public func capabilities(for pluginId: String) -> Set<PluginCapability> {
        guard let granted = grantedCapabilities[pluginId] else {
            return []
        }
        return PluginCapability.parse(capabilities: Array(granted))
    }
}

// MARK: - InstalledPluginInfo

/// Persistent information about an installed plugin.
public struct InstalledPluginInfo: Codable, Equatable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        pluginId: String,
        version: String,
        installedAt: Date,
        installPath: String,
        source: PluginSource
    ) {
        self.pluginId = pluginId
        self.version = version
        self.installedAt = installedAt
        self.installPath = installPath
        self.source = source
    }

    // MARK: Public

    /// Plugin identifier.
    public let pluginId: String

    /// Installed version.
    public let version: String

    /// When the plugin was installed.
    public let installedAt: Date

    /// Path where the plugin is installed (relative to plugin root).
    public let installPath: String

    /// Where the plugin came from.
    public let source: PluginSource
}

// MARK: - PluginSource

/// Source from which a plugin was installed.
public enum PluginSource: Codable, Equatable, Hashable, Sendable {
    /// Built-in plugin bundled with Fig.
    case builtin

    /// Installed from the Farmer's Market registry.
    case marketplace(registryId: String)

    /// Installed from a local .figplugin file.
    case local(originalPath: String)

    /// Installed from a URL.
    case url(String)
}

// MARK: - PluginHookResult

/// Result of executing a plugin hook.
public struct PluginHookResult: Sendable {
    // MARK: Lifecycle

    public init(
        pluginId: String,
        hookEvent: String,
        success: Bool,
        output: [String: AnyCodable]? = nil,
        error: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.pluginId = pluginId
        self.hookEvent = hookEvent
        self.success = success
        self.output = output
        self.error = error
        self.duration = duration
    }

    // MARK: Public

    /// ID of the plugin that executed the hook.
    public let pluginId: String

    /// The hook event that was handled.
    public let hookEvent: String

    /// Whether the hook executed successfully.
    public let success: Bool

    /// Output data from the hook (if any).
    public let output: [String: AnyCodable]?

    /// Error message if the hook failed.
    public let error: String?

    /// How long the hook took to execute.
    public let duration: TimeInterval
}

// MARK: - HookExecutionContext

/// Context passed to plugin hooks during execution.
public struct HookExecutionContext: Sendable {
    // MARK: Lifecycle

    public init(
        event: String,
        toolName: String? = nil,
        toolInput: String? = nil,
        toolOutput: String? = nil,
        projectPath: URL? = nil,
        filePath: String? = nil,
        additionalData: [String: AnyCodable] = [:]
    ) {
        self.event = event
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.projectPath = projectPath
        self.filePath = filePath
        self.additionalData = additionalData
    }

    // MARK: Public

    /// The hook event type (e.g., "PreToolUse", "PostToolUse").
    public let event: String

    /// Tool name for tool-related hooks (e.g., "Bash", "Write").
    public let toolName: String?

    /// Tool input for tool-related hooks.
    public let toolInput: String?

    /// Tool output for PostToolUse hooks.
    public let toolOutput: String?

    /// Current project path.
    public let projectPath: URL?

    /// Affected file path (for Write, Edit hooks).
    public let filePath: String?

    /// Additional context data.
    public let additionalData: [String: AnyCodable]

    /// Convert to a dictionary for passing to Lua.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["event": event]

        if let toolName {
            dict["toolName"] = toolName
        }
        if let toolInput {
            dict["toolInput"] = toolInput
        }
        if let toolOutput {
            dict["toolOutput"] = toolOutput
        }
        if let projectPath {
            dict["projectPath"] = projectPath.path
        }
        if let filePath {
            dict["filePath"] = filePath
        }

        for (key, value) in self.additionalData {
            dict[key] = value.value
        }

        return dict
    }
}
