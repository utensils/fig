import Foundation
import lua4swift
import OSLog
import SwiftyLua

// MARK: - LuaSandbox

/// A sandboxed Lua virtual machine with restricted capabilities.
///
/// Security measures implemented:
/// - Removes dangerous functions (`os.execute`, `io.*`, `debug.*`, `loadfile`, `dofile`)
/// - Restricts file access to the plugin directory
/// - Provides capability-based API exposure
///
/// The sandbox uses SwiftyLua/lua4swift under the hood but applies security restrictions
/// before any plugin code can execute.
///
/// - Note: This class is `@unchecked Sendable` because Lua VMs
///   are not inherently thread-safe. All access should be through the `LuaPluginService` actor.
public final class LuaSandbox: @unchecked Sendable {
    // MARK: Lifecycle

    /// Creates a new sandboxed Lua VM.
    ///
    /// - Parameters:
    ///   - capabilities: Set of capabilities granted to the plugin
    ///   - pluginPath: Path to the plugin directory (for sandboxed file access)
    /// - Throws: `PluginError.loadFailed` if sandbox configuration fails
    public init(
        capabilities: Set<PluginCapability>,
        pluginPath: URL
    ) throws {
        self.capabilities = capabilities
        self.pluginPath = pluginPath

        // Create VM with standard libraries, then restrict them
        self.vm = LuaVM(openLibs: true)

        try self.configureSandbox()

        Log.general.debug("Created Lua sandbox for plugin at \(pluginPath.path)")
    }

    deinit {
        Log.general.debug("Lua sandbox destroyed for \(self.pluginPath.path)")
    }

    // MARK: Public

    /// Gets the last error message from the Lua VM.
    public var lastError: String?

    /// The capabilities granted to this sandbox.
    public let capabilities: Set<PluginCapability>

    /// Path to the plugin directory.
    public let pluginPath: URL

    /// The underlying LuaVM instance.
    public let vm: LuaVM

    /// Loads a Lua file into the sandbox.
    ///
    /// - Parameter url: Path to the Lua file
    /// - Throws: `PluginError.securityViolation` if file is outside plugin directory,
    ///           `PluginError.loadFailed` if the file cannot be loaded
    public func loadFile(_ url: URL) throws {
        // Verify file is within plugin directory
        let resolvedPath = url.standardizedFileURL.path
        let pluginBasePath = self.pluginPath.standardizedFileURL.path

        guard resolvedPath.hasPrefix(pluginBasePath) else {
            throw PluginError.securityViolation(
                reason: "Cannot load files outside plugin directory: \(url.path)"
            )
        }

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw PluginError.loadFailed(
                id: self.pluginPath.lastPathComponent,
                reason: "File not found: \(url.lastPathComponent)"
            )
        }

        do {
            try self.vm.execute(url: url)
        } catch {
            throw PluginError.luaError(message: error.localizedDescription)
        }
    }

    /// Executes Lua code string in the sandbox.
    ///
    /// - Parameter code: Lua code to execute
    /// - Returns: Execution result
    /// - Throws: `PluginError.luaError` if execution fails
    @discardableResult
    public func execute(_ code: String) throws -> VirtualMachine.EvalResults {
        do {
            return try self.vm.execute(string: code)
        } catch {
            throw PluginError.luaError(message: error.localizedDescription)
        }
    }

    /// Calls a global Lua function by name.
    ///
    /// - Parameters:
    ///   - name: Name of the function
    ///   - args: Arguments to pass to the function
    /// - Returns: Result of the function call
    /// - Throws: `PluginError.functionNotFound` if function doesn't exist,
    ///           `PluginError.executionFailed` if execution fails
    public func call(_ name: String, args: [Value] = []) throws -> FunctionResults {
        guard let function = vm.globals[name] as? Function else {
            throw PluginError.functionNotFound(name: name)
        }

        let result = function.call(args)
        if case let .error(message) = result {
            throw PluginError.executionFailed(
                id: self.pluginPath.lastPathComponent,
                function: name,
                reason: message
            )
        }

        return result
    }

    /// Checks if a global function exists.
    ///
    /// - Parameter name: Name of the function
    /// - Returns: True if the function exists
    public func hasFunction(_ name: String) -> Bool {
        self.vm.globals[name] is Function
    }

    /// Gets a global value.
    public func getGlobal(_ name: String) -> Value? {
        let value = self.vm.globals[name]
        // Return nil for Lua nil values
        if value is Nil {
            return nil
        }
        return value
    }

    /// Sets a global value.
    public func setGlobal(_ name: String, value: Value) {
        self.vm.globals[name] = value
    }

    /// Sets a global value to nil.
    public func setGlobalNil(_ name: String) {
        // Use Lua code to set the value to nil
        _ = try? self.execute("\(name) = nil")
    }

    /// Creates a Lua table.
    public func createTable() -> Table {
        self.vm.vm.createTable()
    }

    /// Creates a Lua table with a dictionary of string keys.
    public func createTable(from dict: [String: Any]) -> Table {
        let table = self.vm.vm.createTable()
        for (key, value) in dict {
            if let luaValue = anyToLuaValue(value) {
                table[key] = luaValue
            }
        }
        return table
    }

    /// Registers a Swift function as a global Lua function.
    ///
    /// - Parameters:
    ///   - name: Global name for the function
    ///   - parameters: Type checkers for parameters
    ///   - function: Swift function to register
    public func registerFunction(
        _ name: String,
        parameters: [TypeChecker] = [],
        function: @escaping SwiftFunction
    ) {
        let descriptor = FunctionDescriptor(name: name, parameters: parameters, fn: function)
        self.vm.registerFunction(descriptor)
    }

    /// Registers a table of functions as a Lua library.
    ///
    /// - Parameters:
    ///   - name: Library name (global table name)
    ///   - functions: Array of function descriptors
    public func registerLibrary(
        _ name: String,
        functions: [FunctionDescriptor]
    ) {
        let library = self.vm.vm.createTable()
        self.vm.registerFunctions(functions, library: library)
        self.vm.globals[name] = library
    }

    // MARK: Private

    /// Configures the sandbox by removing dangerous functions.
    private func configureSandbox() throws {
        // Remove dangerous global functions using Lua code
        self.removeDangerousGlobals()

        // Sandbox the os library
        self.sandboxOsLibrary()

        // Remove io library entirely
        self.removeLibrary("io")

        // Remove debug library entirely (but keep reference for function calls)
        // Note: debug.traceback is used by lua4swift for error handling,
        // so we need to be careful here
        self.sandboxDebugLibrary()

        // Sandbox package library
        self.sandboxPackageLibrary()

        // Add safe utility functions
        self.addSafeUtilities()
    }

    /// Removes dangerous global functions.
    private func removeDangerousGlobals() {
        let dangerous = [
            "dofile",
            "loadfile",
            "load",
            "loadstring",
        ]

        for name in dangerous {
            _ = try? self.execute("\(name) = nil")
        }
    }

    /// Sandboxes the os library, keeping only safe functions.
    private func sandboxOsLibrary() {
        // Remove dangerous os functions using Lua code
        let dangerous = [
            "execute", "exit", "getenv", "remove", "rename",
            "setlocale", "tmpname",
        ]

        for name in dangerous {
            _ = try? self.execute("os.\(name) = nil")
        }
    }

    /// Removes a library entirely.
    private func removeLibrary(_ name: String) {
        _ = try? self.execute("\(name) = nil")
    }

    /// Sandboxes the debug library.
    private func sandboxDebugLibrary() {
        // Keep only traceback for error handling, remove everything else
        let toRemove = [
            "debug", "getfenv", "gethook", "getinfo", "getlocal",
            "getmetatable", "getregistry", "getupvalue", "getuservalue",
            "setfenv", "sethook", "setlocal", "setmetatable",
            "setupvalue", "setuservalue", "upvalueid", "upvaluejoin",
        ]

        for name in toRemove {
            _ = try? self.execute("debug.\(name) = nil")
        }
    }

    /// Sandboxes the package library.
    private func sandboxPackageLibrary() {
        // Remove dangerous package functions
        _ = try? self.execute("package.loadlib = nil")
        _ = try? self.execute("package.searchpath = nil")
        _ = try? self.execute("package.searchers = nil")
        _ = try? self.execute("package.loaders = nil")
    }

    /// Adds safe utility functions.
    private func addSafeUtilities() {
        // Register a Swift callback for logging
        self.registerFunction("__fig_log", parameters: [String.arg]) { args in
            let message = args.string
            Log.general.info("Lua: \(message)")
            return .nothing
        }

        // Create a safe print function in Lua that formats args and calls our callback
        _ = try? self.execute("""
        function print(...)
            local args = {...}
            local parts = {}
            for i, v in ipairs(args) do
                parts[i] = tostring(v)
            end
            __fig_log(table.concat(parts, "\\t"))
        end
        """)
    }

    /// Converts a Swift Any value to a Lua Value.
    private func anyToLuaValue(_ value: Any) -> Value? {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return Double(int)
        case let double as Double:
            return double
        case let bool as Bool:
            return bool
        case let dict as [String: Any]:
            return self.createTable(from: dict)
        case let array as [Any]:
            let table = self.vm.vm.createTable(array.count, keyCapacity: 0)
            for (index, item) in array.enumerated() {
                if let luaValue = anyToLuaValue(item) {
                    table[index + 1] = luaValue // Lua arrays are 1-indexed
                }
            }
            return table
        default:
            return nil
        }
    }
}
