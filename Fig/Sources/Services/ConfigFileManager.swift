import Foundation
import OSLog

// MARK: - ConfigFileError

/// Errors that can occur during configuration file operations.
enum ConfigFileError: Error, LocalizedError {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case invalidJSON(URL, underlying: Error)
    case writeError(URL, underlying: Error)
    case backupFailed(URL, underlying: Error)
    case circularSymlink(URL)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(url):
            "File not found: \(url.path)"
        case let .permissionDenied(url):
            "Permission denied: \(url.path). Check file permissions."
        case let .invalidJSON(url, underlying):
            "Invalid JSON in \(url.lastPathComponent): \(underlying.localizedDescription)"
        case let .writeError(url, underlying):
            "Failed to write \(url.lastPathComponent): \(underlying.localizedDescription)"
        case let .backupFailed(url, underlying):
            "Failed to create backup for \(url.lastPathComponent): \(underlying.localizedDescription)"
        case let .circularSymlink(url):
            "Circular symlink detected at \(url.path)"
        }
    }
}

// MARK: - ConfigFileManager

/// Actor responsible for reading and writing Claude Code configuration files.
///
/// This service provides thread-safe file I/O with automatic backups before writes,
/// file change monitoring, and graceful handling of missing or malformed files.
actor ConfigFileManager {
    // MARK: Lifecycle

    private init() {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
    }

    // MARK: Internal

    /// Shared instance for app-wide configuration management.
    static let shared = ConfigFileManager()

    // MARK: - Standard Paths

    /// Path to the global Claude config file (~/.claude.json).
    var globalConfigURL: URL {
        self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    /// Path to the global settings directory (~/.claude).
    var globalSettingsDirectory: URL {
        self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    /// Path to the global settings file (~/.claude/settings.json).
    var globalSettingsURL: URL {
        self.globalSettingsDirectory.appendingPathComponent("settings.json")
    }

    /// Returns the project settings directory for a given project path.
    func projectSettingsDirectory(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".claude")
    }

    /// Returns the project settings file for a given project path.
    func projectSettingsURL(for projectPath: URL) -> URL {
        self.projectSettingsDirectory(for: projectPath).appendingPathComponent("settings.json")
    }

    /// Returns the project local settings file for a given project path.
    func projectLocalSettingsURL(for projectPath: URL) -> URL {
        self.projectSettingsDirectory(for: projectPath).appendingPathComponent("settings.local.json")
    }

    /// Returns the MCP config file for a given project path.
    func mcpConfigURL(for projectPath: URL) -> URL {
        projectPath.appendingPathComponent(".mcp.json")
    }

    // MARK: - Reading Files

    /// Reads and decodes a JSON configuration file.
    ///
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - url: The URL of the file to read.
    /// - Returns: The decoded value, or nil if the file doesn't exist.
    /// - Throws: `ConfigFileError` if the file exists but cannot be read or parsed.
    func read<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T? {
        let resolvedURL = try resolveSymlinks(url)

        guard self.fileManager.fileExists(atPath: resolvedURL.path) else {
            Log.fileIO.debug("File not found (expected): \(url.path)")
            return nil
        }

        guard self.fileManager.isReadableFile(atPath: resolvedURL.path) else {
            Log.fileIO.error("Permission denied: \(url.path)")
            throw ConfigFileError.permissionDenied(url)
        }

        do {
            let data = try Data(contentsOf: resolvedURL)
            let decoded = try decoder.decode(type, from: data)
            Log.fileIO.debug("Successfully read: \(url.path)")
            return decoded
        } catch let error as DecodingError {
            Log.fileIO.error("JSON decode error in \(url.path): \(error)")
            throw ConfigFileError.invalidJSON(url, underlying: error)
        } catch {
            Log.fileIO.error("Read error for \(url.path): \(error)")
            throw ConfigFileError.invalidJSON(url, underlying: error)
        }
    }

    /// Reads the global legacy config file (~/.claude.json).
    func readGlobalConfig() async throws -> LegacyConfig? {
        try await self.read(LegacyConfig.self, from: self.globalConfigURL)
    }

    /// Reads the global settings file (~/.claude/settings.json).
    func readGlobalSettings() async throws -> ClaudeSettings? {
        try await self.read(ClaudeSettings.self, from: self.globalSettingsURL)
    }

    /// Reads project-specific settings.
    func readProjectSettings(for projectPath: URL) async throws -> ClaudeSettings? {
        try await self.read(ClaudeSettings.self, from: self.projectSettingsURL(for: projectPath))
    }

    /// Reads project local settings (gitignored overrides).
    func readProjectLocalSettings(for projectPath: URL) async throws -> ClaudeSettings? {
        try await self.read(ClaudeSettings.self, from: self.projectLocalSettingsURL(for: projectPath))
    }

    /// Reads the MCP configuration for a project.
    func readMCPConfig(for projectPath: URL) async throws -> MCPConfig? {
        try await self.read(MCPConfig.self, from: self.mcpConfigURL(for: projectPath))
    }

    // MARK: - Writing Files

    /// Writes a value to a JSON configuration file with automatic backup.
    ///
    /// - Parameters:
    ///   - value: The value to encode and write.
    ///   - url: The destination URL.
    /// - Throws: `ConfigFileError` if the write fails.
    func write(_ value: some Encodable, to url: URL) async throws {
        // Create backup if file exists
        if self.fileManager.fileExists(atPath: url.path) {
            try await self.createBackup(of: url)
        }

        // Ensure parent directory exists
        let parentDirectory = url.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: parentDirectory.path) {
            do {
                try self.fileManager.createDirectory(
                    at: parentDirectory,
                    withIntermediateDirectories: true
                )
                Log.fileIO.debug("Created directory: \(parentDirectory.path)")
            } catch {
                Log.fileIO.error("Failed to create directory \(parentDirectory.path): \(error)")
                throw ConfigFileError.writeError(url, underlying: error)
            }
        }

        // Encode and write
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            Log.fileIO.info("Successfully wrote: \(url.path)")
        } catch let error as EncodingError {
            Log.fileIO.error("JSON encode error for \(url.path): \(error)")
            throw ConfigFileError.writeError(url, underlying: error)
        } catch {
            Log.fileIO.error("Write error for \(url.path): \(error)")
            throw ConfigFileError.writeError(url, underlying: error)
        }
    }

    /// Writes global settings to ~/.claude/settings.json.
    func writeGlobalSettings(_ settings: ClaudeSettings) async throws {
        try await self.write(settings, to: self.globalSettingsURL)
    }

    /// Writes project settings.
    func writeProjectSettings(_ settings: ClaudeSettings, for projectPath: URL) async throws {
        try await self.write(settings, to: self.projectSettingsURL(for: projectPath))
    }

    /// Writes project local settings.
    func writeProjectLocalSettings(_ settings: ClaudeSettings, for projectPath: URL) async throws {
        try await self.write(settings, to: self.projectLocalSettingsURL(for: projectPath))
    }

    /// Writes MCP configuration for a project.
    func writeMCPConfig(_ config: MCPConfig, for projectPath: URL) async throws {
        try await self.write(config, to: self.mcpConfigURL(for: projectPath))
    }

    // MARK: - File Watching

    /// Starts watching a file for external changes.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to watch.
    ///   - handler: Callback invoked when the file changes.
    func startWatching(_ url: URL, handler: @escaping (URL) -> Void) {
        // Store handler for this specific URL
        self.changeHandlers[url] = handler

        guard self.fileManager.fileExists(atPath: url.path) else {
            Log.fileIO.warning("Cannot watch non-existent file: \(url.path)")
            return
        }

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            Log.fileIO.warning("Cannot open file for watching: \(url.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .utility)
        )

        let watchedURL = url
        source.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            Task { @Sendable in
                await self.handleFileChange(url: watchedURL)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        // Cancel existing watcher if any
        self.watchers[url]?.cancel()
        self.watchers[url] = source

        source.resume()
        Log.fileIO.debug("Started watching: \(url.path)")
    }

    /// Stops watching a file.
    func stopWatching(_ url: URL) {
        self.watchers[url]?.cancel()
        self.watchers.removeValue(forKey: url)
        self.changeHandlers.removeValue(forKey: url)
        Log.fileIO.debug("Stopped watching: \(url.path)")
    }

    /// Stops all file watchers.
    func stopAllWatchers() {
        for (url, source) in self.watchers {
            source.cancel()
            Log.fileIO.debug("Stopped watching: \(url.path)")
        }
        self.watchers.removeAll()
        self.changeHandlers.removeAll()
    }

    // MARK: - Utilities

    /// Checks if a file exists at the given URL.
    func fileExists(at url: URL) -> Bool {
        self.fileManager.fileExists(atPath: url.path)
    }

    /// Deletes a file at the given URL.
    func delete(at url: URL) async throws {
        guard self.fileManager.fileExists(atPath: url.path) else {
            return
        }

        // Create backup before deletion
        try await self.createBackup(of: url)

        try self.fileManager.removeItem(at: url)
        Log.fileIO.info("Deleted file: \(url.path)")
    }

    // MARK: Private

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Active file watchers keyed by URL.
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]

    /// Callback for file change notifications.
    private var changeHandlers: [URL: (URL) -> Void] = [:]

    /// Maximum symlink depth to prevent infinite loops.
    private let maxSymlinkDepth = 10

    // MARK: - Backups

    /// Creates a timestamped backup of a file.
    private func createBackup(of url: URL) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let backupName = "\(url.lastPathComponent).backup.\(timestamp)"
        let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)

        do {
            try self.fileManager.copyItem(at: url, to: backupURL)
            Log.fileIO.debug("Created backup: \(backupURL.path)")
        } catch {
            Log.fileIO.error("Failed to create backup of \(url.path): \(error)")
            throw ConfigFileError.backupFailed(url, underlying: error)
        }
    }

    private func handleFileChange(url: URL) {
        Log.fileIO.info("File changed externally: \(url.path)")
        self.changeHandlers[url]?(url)
    }

    // MARK: - Symlink Resolution

    /// Resolves symlinks while detecting circular references.
    private func resolveSymlinks(_ url: URL, depth: Int = 0) throws -> URL {
        guard depth < self.maxSymlinkDepth else {
            throw ConfigFileError.circularSymlink(url)
        }

        let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard resourceValues?.isSymbolicLink == true else {
            return url
        }

        let resolved = url.resolvingSymlinksInPath()
        if resolved == url {
            throw ConfigFileError.circularSymlink(url)
        }

        return try self.resolveSymlinks(resolved, depth: depth + 1)
    }
}
