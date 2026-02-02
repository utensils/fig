import Foundation

// MARK: - FigError

/// Centralized error type for the Fig application.
///
/// All errors in the application should be converted to `FigError` before
/// being presented to the user, ensuring consistent error messages and
/// recovery suggestions.
enum FigError: Error, LocalizedError, Sendable {
    // MARK: - File Errors

    /// A required file was not found.
    case fileNotFound(path: String)

    /// Permission was denied when accessing a file.
    case permissionDenied(path: String)

    /// The file contains invalid JSON.
    case invalidJSON(path: String, line: Int?)

    /// Failed to write to a file.
    case writeFailed(path: String, reason: String)

    /// Failed to create a backup.
    case backupFailed(path: String)

    // MARK: - Configuration Errors

    /// The configuration is invalid.
    case invalidConfiguration(message: String)

    /// A required configuration key is missing.
    case missingConfigKey(key: String)

    /// A configuration value has an invalid type.
    case invalidConfigValue(key: String, expected: String, got: String)

    /// A general configuration error.
    case configurationError(message: String)

    // MARK: - Project Errors

    /// The specified project was not found.
    case projectNotFound(path: String)

    /// The project configuration is corrupt.
    case corruptProjectConfig(path: String)

    // MARK: - Network Errors

    /// A network request failed.
    case networkError(message: String)

    /// The server returned an unexpected response.
    case invalidResponse(statusCode: Int)

    // MARK: - General Errors

    /// An unknown error occurred.
    case unknown(message: String)

    /// An operation was cancelled.
    case cancelled

    // MARK: Internal

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .permissionDenied(path):
            return "Permission denied: \(path)"
        case let .invalidJSON(path, line):
            if let line {
                return "Invalid JSON at line \(line) in \(path)"
            }
            return "Invalid JSON in \(path)"
        case let .writeFailed(path, reason):
            return "Failed to write to \(path): \(reason)"
        case let .backupFailed(path):
            return "Failed to create backup for \(path)"
        case let .invalidConfiguration(message):
            return "Invalid configuration: \(message)"
        case let .missingConfigKey(key):
            return "Missing required configuration key: \(key)"
        case let .invalidConfigValue(key, expected, got):
            return "Invalid value for '\(key)': expected \(expected), got \(got)"
        case let .configurationError(message):
            return "Configuration error: \(message)"
        case let .projectNotFound(path):
            return "Project not found: \(path)"
        case let .corruptProjectConfig(path):
            return "Corrupt project configuration: \(path)"
        case let .networkError(message):
            return "Network error: \(message)"
        case let .invalidResponse(statusCode):
            return "Invalid response (status code: \(statusCode))"
        case let .unknown(message):
            return message
        case .cancelled:
            return "Operation cancelled"
        }
    }

    var failureReason: String? {
        switch self {
        case .fileNotFound:
            "The file does not exist at the specified path."
        case .permissionDenied:
            "The application does not have permission to access this file."
        case .invalidJSON:
            "The file contains malformed JSON that cannot be parsed."
        case .writeFailed:
            "The file system operation could not be completed."
        case .backupFailed:
            "Could not create a backup before modifying the file."
        case .invalidConfiguration:
            "The configuration contains invalid or incompatible settings."
        case .missingConfigKey:
            "A required configuration key was not found."
        case .invalidConfigValue:
            "A configuration value has the wrong type."
        case .configurationError:
            "An error occurred with the configuration."
        case .projectNotFound:
            "The project directory does not exist or is not accessible."
        case .corruptProjectConfig:
            "The project's configuration files are corrupt or unreadable."
        case .networkError:
            "A network communication error occurred."
        case .invalidResponse:
            "The server returned an unexpected or invalid response."
        case .unknown:
            nil
        case .cancelled:
            "The operation was cancelled by the user."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            "Check that the file path is correct."
        case .permissionDenied:
            "Check file permissions or grant the application access in System Settings > Privacy & Security."
        case .invalidJSON:
            "Open the file in a text editor and fix the JSON syntax, or restore from a backup."
        case .writeFailed:
            "Check that the disk is not full and you have write permissions."
        case .backupFailed:
            "Check that there is enough disk space and the directory is writable."
        case .invalidConfiguration:
            "Review the configuration values and correct any errors."
        case .missingConfigKey:
            "Add the required key to your configuration file."
        case .invalidConfigValue:
            "Update the configuration value to use the correct type."
        case .configurationError:
            "Review the configuration and correct any errors."
        case .projectNotFound:
            "Verify the project path exists and try again."
        case .corruptProjectConfig:
            "Try restoring the configuration from a backup or recreate it."
        case .networkError:
            "Check your network connection and try again."
        case .invalidResponse:
            "The service may be experiencing issues. Try again later."
        case .unknown:
            "Try the operation again or restart the application."
        case .cancelled:
            nil
        }
    }
}

// MARK: - Conversion from ConfigFileError

extension FigError {
    /// Creates a FigError from a ConfigFileError.
    init(from configError: ConfigFileError) {
        switch configError {
        case let .fileNotFound(url):
            self = .fileNotFound(path: url.path)
        case let .permissionDenied(url):
            self = .permissionDenied(path: url.path)
        case let .invalidJSON(url, _):
            self = .invalidJSON(path: url.path, line: nil)
        case let .writeError(url, underlying):
            self = .writeFailed(path: url.path, reason: underlying.localizedDescription)
        case let .backupFailed(url, _):
            self = .backupFailed(path: url.path)
        case let .circularSymlink(url):
            self = .invalidConfiguration(message: "Circular symlink at \(url.path)")
        }
    }
}
