import Foundation
import lua4swift
import OSLog

// MARK: - PluginRegistrations

/// Thread-safe storage for plugin registrations.
///
/// This class provides synchronized access to health checks and presets
/// registered by plugins through the Lua API.
final class PluginRegistrations: PluginAPIRegistry, @unchecked Sendable {
    // MARK: Internal

    /// Registered health checks: checkId -> (pluginId, function)
    private(set) var healthChecks: [String: (String, Function)] = [:]

    /// Registered presets: presetId -> (pluginId, options)
    private(set) var presets: [String: (String, Table)] = [:]

    func registerHealthCheck(id: String, pluginId: String, function: Function) {
        self.lock.lock()
        defer { lock.unlock() }
        self.healthChecks[id] = (pluginId, function)
    }

    func registerPreset(id: String, pluginId: String, options: Table) {
        self.lock.lock()
        defer { lock.unlock() }
        self.presets[id] = (pluginId, options)
    }

    func clearRegistrations(for pluginId: String) {
        self.lock.lock()
        defer { lock.unlock() }
        self.healthChecks = self.healthChecks.filter { $0.value.0 != pluginId }
        self.presets = self.presets.filter { $0.value.0 != pluginId }
    }

    func getHealthChecks() -> [String: (String, Function)] {
        self.lock.lock()
        defer { lock.unlock() }
        return self.healthChecks
    }

    func getPresets() -> [String: (String, Table)] {
        self.lock.lock()
        defer { lock.unlock() }
        return self.presets
    }

    // MARK: Private

    private let lock = NSLock()
}

// MARK: - LuaPluginService

/// Actor responsible for managing Lua plugin lifecycle and execution.
///
/// This service handles plugin discovery, loading, unloading, and hook execution.
/// All Lua VM access is serialized through this actor to ensure thread safety.
///
/// Plugin locations searched (in order):
/// 1. Built-in plugins (bundled with Fig)
/// 2. User plugins (~/.fig/plugins/)
/// 3. App support plugins (~/Library/Application Support/Fig/plugins/)
public actor LuaPluginService {
    // MARK: Lifecycle

    private init() {
        self.registrations = PluginRegistrations()
        Log.general.debug("LuaPluginService initialized")
    }

    // MARK: Public

    /// Shared instance for app-wide plugin management.
    public static let shared = LuaPluginService()

    // MARK: - Plugin Discovery

    /// Discovers all plugins from standard locations.
    ///
    /// - Returns: Array of discovered plugins with their manifests
    /// - Throws: If a manifest file is found but cannot be parsed
    public func discoverPlugins() async throws -> [LoadedPlugin] {
        var discovered: [LoadedPlugin] = []

        for location in self.pluginSearchPaths {
            guard self.fileManager.fileExists(atPath: location.path) else {
                continue
            }

            let contents = try fileManager.contentsOfDirectory(
                at: location,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for url in contents {
                var isDirectory: ObjCBool = false
                guard self.fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue
                else {
                    continue
                }

                // Look for plugin manifest
                let manifestURL = url.appendingPathComponent("plugin.json")
                guard self.fileManager.fileExists(atPath: manifestURL.path) else {
                    continue
                }

                do {
                    let manifest = try loadManifest(from: manifestURL)

                    // Check if already discovered (earlier paths take precedence)
                    guard !discovered.contains(where: { $0.id == manifest.id }) else {
                        Log.general.debug("Skipping duplicate plugin: \(manifest.id)")
                        continue
                    }

                    // Check if disabled
                    let state: PluginLifecycleState = self.installationState.isDisabled(manifest.id)
                        ? .disabled
                        : .discovered

                    // Get granted capabilities
                    let grantedCapabilities = self.installationState.capabilities(for: manifest.id)

                    let plugin = LoadedPlugin(
                        manifest: manifest,
                        path: url,
                        state: state,
                        grantedCapabilities: grantedCapabilities
                    )
                    discovered.append(plugin)

                    Log.general.info("Discovered plugin: \(manifest.id) v\(manifest.version) at \(url.path)")

                } catch {
                    Log.general.warning(
                        "Failed to load plugin manifest at \(manifestURL.path): \(error.localizedDescription)"
                    )
                }
            }
        }

        return discovered
    }

    /// Loads and initializes a plugin.
    ///
    /// - Parameter id: The plugin ID to load
    /// - Throws: `PluginError` if loading fails
    public func loadPlugin(id: String) async throws {
        guard let plugin = loadedPlugins[id] else {
            throw PluginError.pluginNotFound(id: id)
        }

        guard plugin.state == .discovered || plugin.state == .error else {
            if plugin.state == .active {
                throw PluginError.alreadyLoaded(id: id)
            }
            if plugin.state == .disabled {
                throw PluginError.loadFailed(id: id, reason: "Plugin is disabled")
            }
            return
        }

        // Update state to loading
        var updatedPlugin = plugin
        updatedPlugin.state = .loading
        self.loadedPlugins[id] = updatedPlugin

        do {
            // Create sandbox with granted capabilities
            let sandbox = try LuaSandbox(
                capabilities: plugin.grantedCapabilities,
                pluginPath: plugin.path
            )

            // Register the Fig API before loading plugin code
            LuaFigAPI.register(with: sandbox, pluginId: id, registry: self.registrations)

            // Load the main Lua file
            let mainFile = plugin.path.appendingPathComponent(plugin.manifest.main)
            try sandbox.loadFile(mainFile)

            // Call plugin's init function if present
            if sandbox.hasFunction("plugin_init") {
                _ = try sandbox.call("plugin_init")
            }

            // Store sandbox and update state
            self.pluginSandboxes[id] = sandbox
            updatedPlugin.state = .active
            updatedPlugin.loadedAt = Date()
            updatedPlugin.error = nil
            self.loadedPlugins[id] = updatedPlugin

            Log.general.info("Loaded plugin: \(id)")

        } catch let error as PluginError {
            updatedPlugin.state = .error
            updatedPlugin.error = error
            loadedPlugins[id] = updatedPlugin
            throw error
        } catch {
            let pluginError = PluginError.loadFailed(id: id, reason: error.localizedDescription)
            updatedPlugin.state = .error
            updatedPlugin.error = pluginError
            self.loadedPlugins[id] = updatedPlugin
            throw pluginError
        }
    }

    /// Unloads a plugin.
    ///
    /// - Parameter id: The plugin ID to unload
    public func unloadPlugin(id: String) async {
        guard var plugin = loadedPlugins[id] else {
            return
        }

        plugin.state = .unloading
        self.loadedPlugins[id] = plugin

        // Call plugin's cleanup function if present
        if let sandbox = pluginSandboxes[id] {
            if sandbox.hasFunction("plugin_cleanup") {
                do {
                    _ = try sandbox.call("plugin_cleanup")
                } catch {
                    Log.general.warning("Plugin \(id) cleanup failed: \(error.localizedDescription)")
                }
            }
        }

        // Remove sandbox and clear registrations
        self.pluginSandboxes.removeValue(forKey: id)
        self.registrations.clearRegistrations(for: id)

        // Update state
        plugin.state = .discovered
        plugin.loadedAt = nil
        self.loadedPlugins[id] = plugin

        Log.general.info("Unloaded plugin: \(id)")
    }

    /// Reloads a plugin (unload then load).
    ///
    /// - Parameter id: The plugin ID to reload
    /// - Throws: `PluginError` if reloading fails
    public func reloadPlugin(id: String) async throws {
        await self.unloadPlugin(id: id)
        try await self.loadPlugin(id: id)
    }

    /// Enables a previously disabled plugin.
    ///
    /// - Parameter id: The plugin ID to enable
    public func enablePlugin(id: String) async {
        self.installationState.disabledPlugins.remove(id)

        if var plugin = loadedPlugins[id], plugin.state == .disabled {
            plugin.state = .discovered
            self.loadedPlugins[id] = plugin
        }

        await self.saveInstallationState()
    }

    /// Disables a plugin.
    ///
    /// - Parameter id: The plugin ID to disable
    public func disablePlugin(id: String) async {
        // Unload if active
        await self.unloadPlugin(id: id)

        self.installationState.disabledPlugins.insert(id)

        if var plugin = loadedPlugins[id] {
            plugin.state = .disabled
            self.loadedPlugins[id] = plugin
        }

        await self.saveInstallationState()
    }

    // MARK: - Hook Execution

    /// Executes all registered hooks for a given event.
    ///
    /// - Parameter context: The hook execution context
    /// - Returns: Array of results from all matching hooks
    public func executeHooks(context: HookExecutionContext) async -> [PluginHookResult] {
        var results: [PluginHookResult] = []

        for (id, plugin) in self.loadedPlugins where plugin.isActive {
            // Check if plugin has registered for this hook
            guard let hooks = plugin.manifest.hooks,
                  hooks.contains(where: { $0.event == context.event })
            else {
                continue
            }

            guard let sandbox = pluginSandboxes[id] else {
                continue
            }

            // Find the handler function name
            let hookRegistration = hooks.first { $0.event == context.event }
            let handlerName = hookRegistration?.handler ?? "on_\(context.event.lowercased())"

            guard sandbox.hasFunction(handlerName) else {
                Log.general.warning("Plugin \(id) registered for \(context.event) but missing handler \(handlerName)")
                continue
            }

            let startTime = Date()

            do {
                // Convert context to Lua table
                let contextTable = sandbox.createTable(from: context.toDictionary())

                // Call the handler
                let result = try sandbox.call(handlerName, args: [contextTable])

                let duration = Date().timeIntervalSince(startTime)

                // Parse result if it's a table
                var output: [String: AnyCodable]?
                if case let .values(values) = result,
                   let table = values.first as? Table
                {
                    output = tableToDict(table)
                }

                results.append(PluginHookResult(
                    pluginId: id,
                    hookEvent: context.event,
                    success: true,
                    output: output,
                    duration: duration
                ))

            } catch {
                let duration = Date().timeIntervalSince(startTime)
                results.append(PluginHookResult(
                    pluginId: id,
                    hookEvent: context.event,
                    success: false,
                    error: error.localizedDescription,
                    duration: duration
                ))

                Log.general.warning(
                    "Plugin \(id) hook \(context.event) failed: \(error.localizedDescription)"
                )
            }
        }

        return results
    }

    // MARK: - Plugin State

    /// Returns all discovered plugins.
    public func getPlugins() -> [LoadedPlugin] {
        Array(self.loadedPlugins.values)
    }

    /// Returns a specific plugin by ID.
    public func getPlugin(id: String) -> LoadedPlugin? {
        self.loadedPlugins[id]
    }

    /// Returns all active plugins.
    public func getActivePlugins() -> [LoadedPlugin] {
        self.loadedPlugins.values.filter(\.isActive)
    }

    // MARK: - Plugin Registrations

    /// Returns all registered health checks from plugins.
    public func getRegisteredHealthChecks() -> [String: (String, Function)] {
        self.registrations.getHealthChecks()
    }

    /// Returns all registered presets from plugins.
    public func getRegisteredPresets() -> [String: (String, Table)] {
        self.registrations.getPresets()
    }

    // MARK: - Health Check Execution

    /// Executes all registered plugin health checks.
    ///
    /// This method iterates through all health checks registered by plugins and
    /// executes them with the provided context, returning the combined findings.
    ///
    /// - Parameter context: The health check context containing configuration data
    /// - Returns: Array of findings from all plugin health checks
    func executeHealthChecks(context: HealthCheckContext) -> [Finding] {
        var findings: [Finding] = []
        let healthChecks = self.registrations.getHealthChecks()

        for (checkId, (pluginId, checkFunction)) in healthChecks {
            // Get the sandbox for this plugin
            guard let sandbox = pluginSandboxes[pluginId] else {
                Log.general.warning("Plugin \(pluginId) has no active sandbox for health check \(checkId)")
                continue
            }

            do {
                let checkFindings = try PluginHealthCheckAdapter.executeCheck(
                    checkId: checkId,
                    pluginId: pluginId,
                    function: checkFunction,
                    sandbox: sandbox,
                    context: context
                )
                findings.append(contentsOf: checkFindings)
            } catch {
                Log.general.warning(
                    "Plugin health check \(checkId) from \(pluginId) failed: \(error.localizedDescription)"
                )
            }
        }

        return findings
    }

    /// Grants capabilities to a plugin.
    ///
    /// - Parameters:
    ///   - pluginId: The plugin ID
    ///   - capabilities: Set of capabilities to grant
    public func grantCapabilities(_ capabilities: Set<PluginCapability>, to pluginId: String) async {
        let capabilityStrings = capabilities.map(\.rawValue)
        var existing = self.installationState.grantedCapabilities[pluginId] ?? []
        existing.formUnion(capabilityStrings)
        self.installationState.grantedCapabilities[pluginId] = existing

        // Update loaded plugin
        if var plugin = loadedPlugins[pluginId] {
            plugin.grantedCapabilities.formUnion(capabilities)
            self.loadedPlugins[pluginId] = plugin
        }

        await self.saveInstallationState()
    }

    /// Revokes capabilities from a plugin.
    ///
    /// - Parameters:
    ///   - pluginId: The plugin ID
    ///   - capabilities: Set of capabilities to revoke
    public func revokeCapabilities(_ capabilities: Set<PluginCapability>, from pluginId: String) async {
        let capabilityStrings = capabilities.map(\.rawValue)
        if var existing = installationState.grantedCapabilities[pluginId] {
            existing.subtract(capabilityStrings)
            self.installationState.grantedCapabilities[pluginId] = existing
        }

        // Update loaded plugin and potentially unload if capabilities changed
        if var plugin = loadedPlugins[pluginId] {
            plugin.grantedCapabilities.subtract(capabilities)
            self.loadedPlugins[pluginId] = plugin

            // If plugin is active and lost capabilities, reload it
            if plugin.isActive {
                try? await self.reloadPlugin(id: pluginId)
            }
        }

        await self.saveInstallationState()
    }

    // MARK: - Initial Setup

    /// Performs initial discovery and loads enabled plugins.
    public func initialize() async {
        await self.loadInstallationState()

        do {
            let discovered = try await discoverPlugins()
            for plugin in discovered {
                self.loadedPlugins[plugin.id] = plugin
            }

            // Auto-load enabled plugins
            for plugin in discovered where plugin.state == .discovered {
                do {
                    try await loadPlugin(id: plugin.id)
                } catch {
                    Log.general.warning("Failed to auto-load plugin \(plugin.id): \(error.localizedDescription)")
                }
            }

            Log.general.info("Plugin system initialized with \(self.loadedPlugins.count) plugins")

        } catch {
            Log.general.error("Plugin discovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: Private

    /// Storage for plugin API registrations (health checks, presets).
    private let registrations: PluginRegistrations

    /// All currently tracked plugins, keyed by ID.
    private var loadedPlugins: [String: LoadedPlugin] = [:]

    /// Lua sandboxes for active plugins, keyed by plugin ID.
    private var pluginSandboxes: [String: LuaSandbox] = [:]

    /// Persistent installation state.
    private var installationState = PluginInstallationState()

    private let fileManager = FileManager.default

    /// Standard plugin search paths.
    private var pluginSearchPaths: [URL] {
        var paths: [URL] = []

        // 1. Built-in plugins (bundled with app)
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("Plugins") {
            paths.append(bundlePath)
        }

        // 2. User plugins (~/.fig/plugins/)
        let userPlugins = self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".fig")
            .appendingPathComponent("plugins")
        paths.append(userPlugins)

        // 3. App support plugins (~/Library/Application Support/Fig/plugins/)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appSupportPlugins = appSupport
                .appendingPathComponent("Fig")
                .appendingPathComponent("plugins")
            paths.append(appSupportPlugins)
        }

        return paths
    }

    /// Path to the installation state file.
    private var installationStateURL: URL {
        self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".fig")
            .appendingPathComponent("plugin-state.json")
    }

    /// Loads the plugin manifest from a URL.
    private func loadManifest(from url: URL) throws -> PluginManifest {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(PluginManifest.self, from: data)
        } catch {
            throw PluginError.manifestInvalid(path: url.path, reason: error.localizedDescription)
        }
    }

    /// Loads the persistent installation state.
    private func loadInstallationState() async {
        guard self.fileManager.fileExists(atPath: self.installationStateURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: installationStateURL)
            self.installationState = try JSONDecoder().decode(PluginInstallationState.self, from: data)
        } catch {
            Log.general.warning("Failed to load plugin state: \(error.localizedDescription)")
        }
    }

    /// Saves the persistent installation state.
    private func saveInstallationState() async {
        do {
            // Ensure directory exists
            let directory = self.installationStateURL.deletingLastPathComponent()
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self.installationState)
            try data.write(to: self.installationStateURL, options: .atomic)
        } catch {
            Log.general.error("Failed to save plugin state: \(error.localizedDescription)")
        }
    }

    /// Converts a Lua table to a Swift dictionary.
    private func tableToDict(_ table: Table) -> [String: AnyCodable] {
        var dict: [String: AnyCodable] = [:]

        // Iterate through table keys
        for key in table.keys() {
            // Only handle string keys for dictionary conversion
            if let stringKey = key as? String {
                let value = table[key]
                dict[stringKey] = self.valueToAnyCodable(value)
            }
        }

        return dict
    }

    /// Converts a Lua value to AnyCodable.
    private func valueToAnyCodable(_ value: Value) -> AnyCodable {
        switch value.kind() {
        case .string:
            return AnyCodable(value as? String ?? "")
        case .number:
            return AnyCodable((value as? Number)?.toDouble() ?? 0)
        case .boolean:
            return AnyCodable(value as? Bool ?? false)
        case .table:
            if let table = value as? Table {
                return AnyCodable(self.tableToDict(table))
            }
            return AnyCodable([:] as [String: Any])
        case .nil:
            return AnyCodable(NSNull())
        default:
            return AnyCodable(NSNull())
        }
    }
}
