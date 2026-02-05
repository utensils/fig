import Foundation

// MARK: - PluginError

/// Errors specific to the Lua plugin system.
public enum PluginError: Error, LocalizedError, Sendable, Equatable {
    /// Plugin was not found at the expected location.
    case pluginNotFound(id: String)

    /// Plugin manifest is missing from the plugin directory.
    case manifestMissing(path: String)

    /// Plugin manifest is invalid or cannot be parsed.
    case manifestInvalid(path: String, reason: String)

    /// Plugin failed to load.
    case loadFailed(id: String, reason: String)

    /// Plugin execution failed.
    case executionFailed(id: String, function: String, reason: String)

    /// Plugin attempted an unauthorized operation.
    case securityViolation(reason: String)

    /// Required Lua function was not found in the plugin.
    case functionNotFound(name: String)

    /// Plugin requested a capability that was not granted.
    case permissionDenied(capability: String)

    /// Plugin execution timed out.
    case timeout(id: String, function: String)

    /// Lua runtime error.
    case luaError(message: String)

    /// Plugin version is incompatible with the current Fig version.
    case versionIncompatible(pluginId: String, required: String, current: String)

    /// Plugin depends on another plugin that is not installed.
    case dependencyMissing(pluginId: String, dependencyId: String)

    /// Plugin is already loaded.
    case alreadyLoaded(id: String)

    /// Plugin installation failed.
    case installFailed(reason: String)

    /// Plugin uninstallation failed.
    case uninstallFailed(id: String, reason: String)

    /// Checksum verification failed.
    case checksumMismatch(expected: String, actual: String)

    /// Signature verification failed.
    case signatureInvalid(reason: String)

    /// Network error during plugin operations.
    case networkError(reason: String)

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case let .pluginNotFound(id):
            "Plugin not found: \(id)"
        case let .manifestMissing(path):
            "Plugin manifest (plugin.json) not found at: \(path)"
        case let .manifestInvalid(path, reason):
            "Invalid plugin manifest at \(path): \(reason)"
        case let .loadFailed(id, reason):
            "Failed to load plugin '\(id)': \(reason)"
        case let .executionFailed(id, function, reason):
            "Plugin '\(id)' function '\(function)' failed: \(reason)"
        case let .securityViolation(reason):
            "Security violation: \(reason)"
        case let .functionNotFound(name):
            "Lua function not found: \(name)"
        case let .permissionDenied(capability):
            "Permission denied: plugin requires '\(capability)' capability"
        case let .timeout(id, function):
            "Plugin '\(id)' function '\(function)' timed out"
        case let .luaError(message):
            "Lua error: \(message)"
        case let .versionIncompatible(pluginId, required, current):
            "Plugin '\(pluginId)' requires Fig version \(required), but current version is \(current)"
        case let .dependencyMissing(pluginId, dependencyId):
            "Plugin '\(pluginId)' requires plugin '\(dependencyId)' which is not installed"
        case let .alreadyLoaded(id):
            "Plugin '\(id)' is already loaded"
        case let .installFailed(reason):
            "Plugin installation failed: \(reason)"
        case let .uninstallFailed(id, reason):
            "Failed to uninstall plugin '\(id)': \(reason)"
        case let .checksumMismatch(expected, actual):
            "Checksum verification failed: expected \(expected), got \(actual)"
        case let .signatureInvalid(reason):
            "Signature verification failed: \(reason)"
        case let .networkError(reason):
            "Network error: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .pluginNotFound:
            "Ensure the plugin is installed in ~/.fig/plugins/"
        case .manifestMissing:
            "Each plugin directory must contain a plugin.json manifest file"
        case .manifestInvalid:
            "Check the plugin's plugin.json file for syntax errors or missing required fields"
        case .loadFailed:
            "Check the plugin's Lua code for syntax errors"
        case .executionFailed:
            "Review the plugin's error handling and contact the plugin author"
        case .securityViolation:
            "The plugin attempted an operation it doesn't have permission for"
        case .functionNotFound:
            "Ensure the plugin exports the required function in its main Lua file"
        case .permissionDenied:
            "Grant the required capability to the plugin in Fig's settings"
        case .timeout:
            "The plugin is taking too long to execute. Check for infinite loops"
        case .luaError:
            "Check the plugin's Lua code for errors"
        case .versionIncompatible:
            "Update Fig to a compatible version or find an older version of the plugin"
        case .dependencyMissing:
            "Install the required dependency plugin first"
        case .alreadyLoaded:
            "The plugin is already running. Reload it if you want to apply changes"
        case .installFailed:
            "Check your network connection and try again"
        case .uninstallFailed:
            "Close any files the plugin may be using and try again"
        case .checksumMismatch:
            "The downloaded file may be corrupted. Try downloading again"
        case .signatureInvalid:
            "Only install plugins from trusted sources"
        case .networkError:
            "Check your internet connection and try again"
        }
    }

    public var failureReason: String? {
        self.errorDescription
    }
}
