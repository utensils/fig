import AppKit
import Foundation
import OSLog

// MARK: - MCPSharingError

/// Errors that can occur during MCP sharing operations.
enum MCPSharingError: Error, LocalizedError {
    case invalidJSON(String)
    case noServersFound
    case serializationFailed(underlying: Error)
    case importFailed(underlying: Error)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .invalidJSON(detail):
            "Invalid JSON: \(detail)"
        case .noServersFound:
            "No MCP servers found in the provided JSON."
        case let .serializationFailed(error):
            "Serialization failed: \(error.localizedDescription)"
        case let .importFailed(error):
            "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - BulkImportResult

/// Result of a bulk import operation.
struct BulkImportResult: Sendable, Equatable {
    let imported: [String]
    let skipped: [String]
    let renamed: [String: String]
    let errors: [String]

    var totalImported: Int {
        self.imported.count + self.renamed.count
    }

    var summary: String {
        var parts: [String] = []
        if !self.imported.isEmpty {
            parts.append("\(self.imported.count) imported")
        }
        if !self.renamed.isEmpty {
            parts.append("\(self.renamed.count) renamed")
        }
        if !self.skipped.isEmpty {
            parts.append("\(self.skipped.count) skipped")
        }
        if !self.errors.isEmpty {
            parts.append("\(self.errors.count) errors")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - MCPSharingService

/// Service for sharing MCP server configurations via clipboard and bulk import/export.
actor MCPSharingService {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    static let shared = MCPSharingService()

    // MARK: - Serialization

    /// Serializes servers to MCPConfig JSON format matching `.mcp.json`.
    ///
    /// When `redactSensitive` is true, replaces sensitive env var values with
    /// `<YOUR_KEY_NAME>` placeholders and sensitive header values with `<YOUR_HEADER_NAME>`.
    nonisolated func serializeToJSON(
        servers: [String: MCPServer],
        redactSensitive: Bool = false
    ) throws -> String {
        let finalServers = redactSensitive ? self.redactServers(servers) : servers
        let config = MCPConfig(mcpServers: finalServers)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(config)
            guard let json = String(data: data, encoding: .utf8) else {
                throw MCPSharingError.serializationFailed(
                    underlying: NSError(
                        domain: "MCPSharingService",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to UTF-8 string"]
                    )
                )
            }
            return json
        } catch let error as MCPSharingError {
            throw error
        } catch {
            throw MCPSharingError.serializationFailed(underlying: error)
        }
    }

    // MARK: - Parsing

    /// Parses JSON text into a dictionary of MCP servers.
    ///
    /// Accepts multiple formats:
    /// - MCPConfig: `{"mcpServers": {"name": {...}, ...}}`
    /// - Flat dict: `{"name": {"command": "..."}, "name2": {...}}`
    /// - Single named: `{"name": {"command": "..."}}`
    /// - Single unnamed: `{"command": "...", "args": [...]}`
    func parseServersFromJSON(_ json: String) throws -> [String: MCPServer] {
        guard let data = json.data(using: .utf8) else {
            throw MCPSharingError.invalidJSON("Input is not valid UTF-8")
        }

        // Try MCPConfig format first
        if let config = try? JSONDecoder().decode(MCPConfig.self, from: data),
           let servers = config.mcpServers, !servers.isEmpty
        {
            return servers
        }

        // Try flat dictionary of servers
        if let dict = try? JSONDecoder().decode([String: MCPServer].self, from: data) {
            // Filter to entries that look like actual servers (have command or url)
            let validServers = dict.filter { $0.value.command != nil || $0.value.url != nil }
            if !validServers.isEmpty {
                return validServers
            }
        }

        // Try single unnamed server
        if let server = try? JSONDecoder().decode(MCPServer.self, from: data),
           server.command != nil || server.url != nil
        {
            return ["server": server]
        }

        throw MCPSharingError.noServersFound
    }

    // MARK: - Sensitive Data Detection

    /// Detects sensitive environment variables and headers across multiple servers.
    func detectSensitiveData(servers: [String: MCPServer]) -> [SensitiveEnvWarning] {
        var warnings: [SensitiveEnvWarning] = []

        for (serverName, server) in servers.sorted(by: { $0.key < $1.key }) {
            // Check env vars
            if let env = server.env {
                for key in env.keys.sorted() {
                    if self.isSensitiveKey(key) {
                        warnings.append(SensitiveEnvWarning(
                            key: "\(serverName).\(key)",
                            reason: self.sensitiveReason(for: key)
                        ))
                    }
                }
            }

            // Check headers
            if let headers = server.headers {
                for key in headers.keys.sorted() {
                    if self.isSensitiveKey(key) {
                        warnings.append(SensitiveEnvWarning(
                            key: "\(serverName).\(key)",
                            reason: self.sensitiveReason(for: key)
                        ))
                    }
                }
            }
        }

        return warnings
    }

    /// Checks if any server has sensitive data.
    func containsSensitiveData(servers: [String: MCPServer]) -> Bool {
        !self.detectSensitiveData(servers: servers).isEmpty
    }

    // MARK: - Clipboard Operations

    /// Writes MCP config JSON to the system clipboard.
    @MainActor
    func writeToClipboard(
        servers: [String: MCPServer],
        redactSensitive: Bool = false
    ) throws {
        let json = try serializeToJSON(servers: servers, redactSensitive: redactSensitive)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    /// Reads text content from the system clipboard.
    @MainActor
    func readFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    // MARK: - Bulk Import

    /// Imports multiple servers into a destination, handling conflicts by strategy.
    func importServers(
        _ servers: [String: MCPServer],
        to destination: CopyDestination,
        strategy: ConflictStrategy,
        configManager: ConfigFileManager = .shared
    ) async throws -> BulkImportResult {
        var imported: [String] = []
        var skipped: [String] = []
        var renamed: [String: String] = [:]
        var errors: [String] = []

        let existingServers = await getExistingServers(
            at: destination,
            configManager: configManager
        )

        // Build a set of all names (existing + already imported) to avoid collisions
        var allNames = Set(existingServers.keys)

        for (name, server) in servers.sorted(by: { $0.key < $1.key }) {
            let hasConflict = allNames.contains(name)

            if hasConflict {
                switch strategy {
                case .skip,
                     .prompt:
                    skipped.append(name)
                    continue

                case .overwrite:
                    do {
                        try await self.writeServer(
                            name: name,
                            server: server,
                            to: destination,
                            configManager: configManager
                        )
                        imported.append(name)
                    } catch {
                        errors.append("\(name): \(error.localizedDescription)")
                    }

                case .rename:
                    let newName = self.generateUniqueName(baseName: name, existingNames: allNames)
                    do {
                        try await self.writeServer(
                            name: newName,
                            server: server,
                            to: destination,
                            configManager: configManager
                        )
                        renamed[name] = newName
                        allNames.insert(newName)
                    } catch {
                        errors.append("\(name): \(error.localizedDescription)")
                    }
                }
            } else {
                do {
                    try await self.writeServer(
                        name: name,
                        server: server,
                        to: destination,
                        configManager: configManager
                    )
                    imported.append(name)
                    allNames.insert(name)
                } catch {
                    errors.append("\(name): \(error.localizedDescription)")
                }
            }
        }

        Log.general.info(
            "Bulk import: \(imported.count) imported, \(renamed.count) renamed, \(skipped.count) skipped, \(errors.count) errors"
        )

        return BulkImportResult(
            imported: imported,
            skipped: skipped,
            renamed: renamed,
            errors: errors
        )
    }

    // MARK: Private

    // MARK: - Sensitive Data Helpers

    private static let sensitivePatterns = [
        "token", "key", "secret", "password", "passwd",
        "credential", "auth", "api",
    ]

    private nonisolated func isSensitiveKey(_ key: String) -> Bool {
        let lowerKey = key.lowercased()
        return Self.sensitivePatterns.contains { lowerKey.contains($0) }
    }

    private func sensitiveReason(for key: String) -> String {
        let lowerKey = key.lowercased()
        if lowerKey.contains("token") {
            return "May contain authentication token"
        } else if lowerKey.contains("key") || lowerKey.contains("api") {
            return "May contain API key"
        } else if lowerKey.contains("secret") {
            return "May contain secret value"
        } else if lowerKey.contains("password") || lowerKey.contains("passwd") {
            return "May contain password"
        } else if lowerKey.contains("credential") || lowerKey.contains("auth") {
            return "May contain credentials"
        }
        return "May contain sensitive data"
    }

    // MARK: - Redaction

    private nonisolated func redactServers(_ servers: [String: MCPServer]) -> [String: MCPServer] {
        var result: [String: MCPServer] = [:]
        for (name, server) in servers {
            result[name] = self.redactServer(server)
        }
        return result
    }

    private nonisolated func redactServer(_ server: MCPServer) -> MCPServer {
        var redacted = server

        // Redact sensitive env vars
        if let env = server.env {
            var redactedEnv: [String: String] = [:]
            for (key, value) in env {
                if self.isSensitiveKey(key) {
                    redactedEnv[key] = "<YOUR_\(key.uppercased())>"
                } else {
                    redactedEnv[key] = value
                }
            }
            redacted.env = redactedEnv
        }

        // Redact sensitive headers
        if let headers = server.headers {
            var redactedHeaders: [String: String] = [:]
            for (key, value) in headers {
                if self.isSensitiveKey(key) {
                    redactedHeaders[key] = "<YOUR_\(key.uppercased())>"
                } else {
                    redactedHeaders[key] = value
                }
            }
            redacted.headers = redactedHeaders
        }

        return redacted
    }

    // MARK: - Name Generation

    private func generateUniqueName(baseName: String, existingNames: Set<String>) -> String {
        var candidate = "\(baseName)-copy"
        var counter = 2

        while existingNames.contains(candidate) {
            candidate = "\(baseName)-copy-\(counter)"
            counter += 1
        }

        return candidate
    }

    // MARK: - Destination Helpers

    private func getExistingServers(
        at destination: CopyDestination,
        configManager: ConfigFileManager
    ) async -> [String: MCPServer] {
        do {
            switch destination {
            case .global:
                let config = try await configManager.readGlobalConfig()
                return config?.mcpServers ?? [:]

            case let .project(path, _):
                let url = URL(fileURLWithPath: path)
                let mcpConfig = try await configManager.readMCPConfig(for: url)
                return mcpConfig?.mcpServers ?? [:]
            }
        } catch {
            Log.general.error("Failed to read servers at destination: \(error)")
            return [:]
        }
    }

    private func writeServer(
        name: String,
        server: MCPServer,
        to destination: CopyDestination,
        configManager: ConfigFileManager
    ) async throws {
        switch destination {
        case .global:
            var config = try await configManager.readGlobalConfig() ?? LegacyConfig()
            if config.mcpServers == nil {
                config.mcpServers = [:]
            }
            config.mcpServers?[name] = server
            try await configManager.writeGlobalConfig(config)

        case let .project(path, _):
            let url = URL(fileURLWithPath: path)
            var mcpConfig = try await configManager.readMCPConfig(for: url)
                ?? MCPConfig(mcpServers: [:])
            if mcpConfig.mcpServers == nil {
                mcpConfig.mcpServers = [:]
            }
            mcpConfig.mcpServers?[name] = server
            try await configManager.writeMCPConfig(mcpConfig, for: url)
        }
    }
}
