import Foundation
import lua4swift
import OSLog

// MARK: - LuaFigAPI

/// Provides the `fig.*` API surface for Lua plugins.
///
/// This class registers Lua functions that allow plugins to interact with Fig's
/// configuration, health check system, and other services. Functions are exposed
/// based on the plugin's granted capabilities.
///
/// ## API Modules
///
/// | Module | Capabilities | Description |
/// |--------|-------------|-------------|
/// | `fig.log` | Always | Logging (debug, info, warning, error) |
/// | `fig.config` | `config:read:*`, `config:write:*` | Read/write settings |
/// | `fig.health` | `health:register`, `health:findings` | Register health checks |
/// | `fig.preset` | `preset:register` | Register permission presets |
/// | `fig.version` | Always | Fig version information |
public enum LuaFigAPI {
    // MARK: Public

    /// Registers the Fig API modules with a Lua sandbox.
    ///
    /// - Parameters:
    ///   - sandbox: The Lua sandbox to register APIs with
    ///   - pluginId: The plugin's identifier (for logging and attribution)
    ///   - registry: Optional registry to store plugin registrations
    public static func register(
        with sandbox: LuaSandbox,
        pluginId: String,
        registry: PluginAPIRegistry? = nil
    ) {
        // Create the main 'fig' table
        let figTable = sandbox.createTable()
        sandbox.setGlobal("fig", value: figTable)

        // Always register version and log
        self.registerVersionAPI(sandbox: sandbox, figTable: figTable)
        self.registerLogAPI(sandbox: sandbox, figTable: figTable, pluginId: pluginId)

        // Register capability-gated APIs
        let capabilities = sandbox.capabilities

        if capabilities.contains(.configReadGlobal) || capabilities.contains(.configReadProject) {
            self.registerConfigReadAPI(sandbox: sandbox, figTable: figTable, capabilities: capabilities)
        }

        if capabilities.contains(.configWriteProject) || capabilities.contains(.configWriteLocal) {
            self.registerConfigWriteAPI(sandbox: sandbox, figTable: figTable, capabilities: capabilities)
        }

        if capabilities.contains(.healthRegister) {
            self.registerHealthAPI(
                sandbox: sandbox,
                figTable: figTable,
                pluginId: pluginId,
                registry: registry
            )
        }

        if capabilities.contains(.presetRegister) {
            self.registerPresetAPI(
                sandbox: sandbox,
                figTable: figTable,
                pluginId: pluginId,
                registry: registry
            )
        }

        if capabilities.contains(.fsReadProject) || capabilities.contains(.fsExists) {
            self.registerFilesystemAPI(sandbox: sandbox, figTable: figTable, capabilities: capabilities)
        }
    }

    // MARK: Private

    // MARK: - Version API

    private static func registerVersionAPI(
        sandbox: LuaSandbox,
        figTable: Table
    ) {
        let versionTable = sandbox.createTable()

        // Get app version from bundle
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        versionTable["app"] = appVersion
        versionTable["build"] = buildNumber
        versionTable["api"] = "1.0" // Plugin API version

        figTable["version"] = versionTable
    }

    // MARK: - Log API

    private static func registerLogAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        pluginId: String
    ) {
        let logTable = sandbox.createTable()

        // fig.log.debug(message)
        let debugFn = sandbox.vm.vm.createFunction([String.arg]) { args in
            let message = args.string
            Log.general.debug("[\(pluginId)] \(message)")
            return .nothing
        }
        logTable["debug"] = debugFn

        // fig.log.info(message)
        let infoFn = sandbox.vm.vm.createFunction([String.arg]) { args in
            let message = args.string
            Log.general.info("[\(pluginId)] \(message)")
            return .nothing
        }
        logTable["info"] = infoFn

        // fig.log.warning(message)
        let warningFn = sandbox.vm.vm.createFunction([String.arg]) { args in
            let message = args.string
            Log.general.warning("[\(pluginId)] \(message)")
            return .nothing
        }
        logTable["warning"] = warningFn

        // fig.log.error(message)
        let errorFn = sandbox.vm.vm.createFunction([String.arg]) { args in
            let message = args.string
            Log.general.error("[\(pluginId)] \(message)")
            return .nothing
        }
        logTable["error"] = errorFn

        figTable["log"] = logTable
    }

    // MARK: - Config Read API

    // TODO: Implement actual config reading. These stubs currently just log requests.
    // Implementation requires passing ConfigFileManager or config values into the API registration.

    private static func registerConfigReadAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        capabilities: Set<PluginCapability>
    ) {
        let configTable = (figTable["config"] as? Table) ?? sandbox.createTable()

        // fig.config.getGlobal(key) -> value
        // TODO: Implement actual global config reading
        if capabilities.contains(.configReadGlobal) {
            let getGlobalFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let key = args.string
                Log.general.debug("Plugin requested global config key: \(key)")
                return .nothing
            }
            configTable["getGlobal"] = getGlobalFn
        }

        // fig.config.getProject(key) -> value
        // TODO: Implement actual project config reading
        if capabilities.contains(.configReadProject) {
            let getProjectFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let key = args.string
                Log.general.debug("Plugin requested project config key: \(key)")
                return .nothing
            }
            configTable["getProject"] = getProjectFn
        }

        figTable["config"] = configTable
    }

    // MARK: - Config Write API

    // TODO: Implement actual config writing. These stubs currently just log requests.
    // Implementation requires async coordination with ConfigFileManager.

    private static func registerConfigWriteAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        capabilities: Set<PluginCapability>
    ) {
        let configTable = (figTable["config"] as? Table) ?? sandbox.createTable()

        // fig.config.setProject(key, value)
        // TODO: Implement actual project config writing
        if capabilities.contains(.configWriteProject) {
            let setProjectFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let key = args.string
                Log.general.debug("Plugin setting project config key: \(key)")
                return .nothing
            }
            configTable["setProject"] = setProjectFn
        }

        // fig.config.setLocal(key, value)
        // TODO: Implement actual local config writing
        if capabilities.contains(.configWriteLocal) {
            let setLocalFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let key = args.string
                Log.general.debug("Plugin setting local config key: \(key)")
                return .nothing
            }
            configTable["setLocal"] = setLocalFn
        }

        figTable["config"] = configTable
    }

    // MARK: - Health API

    private static func registerHealthAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        pluginId: String,
        registry: PluginAPIRegistry?
    ) {
        let healthTable = sandbox.createTable()

        // fig.health.registerCheck(id, checkFunction)
        let registerCheckFn = sandbox.vm.vm.createFunction([String.arg, Function.arg]) { args in
            let checkId = args.string
            let checkFn = args.function

            let fullId = "\(pluginId).\(checkId)"
            registry?.registerHealthCheck(id: fullId, pluginId: pluginId, function: checkFn)

            Log.general.info("Plugin \(pluginId) registered health check: \(checkId)")
            return .nothing
        }
        healthTable["registerCheck"] = registerCheckFn

        // fig.health.finding(options) -> finding table
        let findingFn = sandbox.vm.vm.createFunction([Table.arg]) { args in
            // Just pass through the table - it will be interpreted by the health check runner
            let options = args.table
            return .value(options)
        }
        healthTable["finding"] = findingFn

        // fig.health.severity enum
        let severityTable = sandbox.createTable()
        severityTable["CRITICAL"] = "critical"
        severityTable["WARNING"] = "warning"
        severityTable["SUGGESTION"] = "suggestion"
        severityTable["INFO"] = "info"
        healthTable["severity"] = severityTable

        // fig.health.autoFix helpers
        let autoFixTable = sandbox.createTable()

        // fig.health.autoFix.createLocalSettings()
        let createLocalSettingsFn = sandbox.vm.vm.createFunction([]) { _ in
            let fix = sandbox.createTable()
            fix["type"] = "createLocalSettings"
            return .value(fix)
        }
        autoFixTable["createLocalSettings"] = createLocalSettingsFn

        // fig.health.autoFix.addRule(rule)
        let addRuleFn = sandbox.vm.vm.createFunction([String.arg]) { args in
            let rule = args.string
            let fix = sandbox.createTable()
            fix["type"] = "addRule"
            fix["rule"] = rule
            return .value(fix)
        }
        autoFixTable["addRule"] = addRuleFn

        healthTable["autoFix"] = autoFixTable

        figTable["health"] = healthTable
    }

    // MARK: - Preset API

    private static func registerPresetAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        pluginId: String,
        registry: PluginAPIRegistry?
    ) {
        let presetTable = sandbox.createTable()

        // fig.preset.registerPermissionPreset(options)
        let registerPresetFn = sandbox.vm.vm.createFunction([Table.arg]) { args in
            let options = args.table

            guard let presetId = options["id"] as? String else {
                return .error("Preset must have an 'id' field")
            }

            let fullId = "\(pluginId).\(presetId)"
            registry?.registerPreset(id: fullId, pluginId: pluginId, options: options)

            Log.general.info("Plugin \(pluginId) registered preset: \(presetId)")
            return .nothing
        }
        presetTable["registerPermissionPreset"] = registerPresetFn

        figTable["preset"] = presetTable
    }

    // MARK: - Filesystem API

    private static func registerFilesystemAPI(
        sandbox: LuaSandbox,
        figTable: Table,
        capabilities: Set<PluginCapability>
    ) {
        let fsTable = sandbox.createTable()

        // fig.fs.exists(path) -> boolean
        if capabilities.contains(.fsExists) {
            let existsFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let path = args.string

                // Only allow checking within plugin directory for safety
                let fullPath = sandbox.pluginPath.appendingPathComponent(path)
                let resolvedPath = fullPath.standardizedFileURL.path
                let pluginBasePath = sandbox.pluginPath.standardizedFileURL.path

                guard resolvedPath.hasPrefix(pluginBasePath) else {
                    Log.general.warning("Plugin attempted to check file outside sandbox: \(path)")
                    return .value(false)
                }

                let exists = FileManager.default.fileExists(atPath: resolvedPath)
                return .value(exists)
            }
            fsTable["exists"] = existsFn
        }

        // fig.fs.readFile(path) -> string or nil
        if capabilities.contains(.fsReadProject) {
            let readFileFn = sandbox.vm.vm.createFunction([String.arg]) { args in
                let path = args.string

                // Only allow reading within plugin directory for safety
                let fullPath = sandbox.pluginPath.appendingPathComponent(path)
                let resolvedPath = fullPath.standardizedFileURL.path
                let pluginBasePath = sandbox.pluginPath.standardizedFileURL.path

                guard resolvedPath.hasPrefix(pluginBasePath) else {
                    Log.general.warning("Plugin attempted to read file outside sandbox: \(path)")
                    return .nothing
                }

                guard let contents = try? String(contentsOfFile: resolvedPath, encoding: .utf8) else {
                    return .nothing
                }

                return .value(contents)
            }
            fsTable["readFile"] = readFileFn
        }

        figTable["fs"] = fsTable
    }
}

// MARK: - PluginAPIRegistry

/// Protocol for receiving plugin API registrations.
///
/// Implementations of this protocol can receive health check and preset registrations
/// from plugins via the Lua API.
public protocol PluginAPIRegistry: AnyObject {
    /// Called when a plugin registers a health check.
    func registerHealthCheck(id: String, pluginId: String, function: Function)

    /// Called when a plugin registers a preset.
    func registerPreset(id: String, pluginId: String, options: Table)
}
