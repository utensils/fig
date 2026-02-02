import Foundation
import OSLog

// MARK: - ConflictStrategy

/// Strategy for handling server name conflicts during copy.
enum ConflictStrategy: String, CaseIterable, Identifiable {
    case prompt    // Ask for each conflict
    case overwrite // Replace existing
    case rename    // Auto-suffix with -copy
    case skip      // Skip conflicts

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .prompt: "Ask for each"
        case .overwrite: "Overwrite existing"
        case .rename: "Rename (add -copy suffix)"
        case .skip: "Skip conflicts"
        }
    }
}

// MARK: - CopyConflict

/// Represents a conflict found during copy operation.
struct CopyConflict: Identifiable {
    let id = UUID()
    let serverName: String
    let existingServer: MCPServer
    let newServer: MCPServer
    var resolution: ConflictResolution = .skip

    enum ConflictResolution {
        case overwrite
        case rename(String)
        case skip
    }
}

// MARK: - CopyDestination

/// Destination for copying an MCP server.
enum CopyDestination: Identifiable, Hashable {
    case global
    case project(path: String, name: String)

    var id: String {
        switch self {
        case .global:
            "global"
        case let .project(path, _):
            path
        }
    }

    var displayName: String {
        switch self {
        case .global:
            "Global Configuration"
        case let .project(_, name):
            name
        }
    }

    var icon: String {
        switch self {
        case .global:
            "globe"
        case .project:
            "folder"
        }
    }
}

// MARK: - SensitiveEnvWarning

/// Warning about potentially sensitive environment variables.
struct SensitiveEnvWarning: Identifiable {
    let id = UUID()
    let key: String
    let reason: String
}

// MARK: - CopyResult

/// Result of a copy operation.
struct CopyResult {
    let serverName: String
    let destination: CopyDestination
    let success: Bool
    let message: String
    let renamed: Bool
    let newName: String?
}

// MARK: - MCPServerCopyService

/// Service for copying MCP server configurations between projects and global config.
actor MCPServerCopyService {
    // MARK: Internal

    static let shared = MCPServerCopyService()

    /// Checks for conflicts when copying a server to a destination.
    func checkConflict(
        serverName: String,
        server: MCPServer,
        destination: CopyDestination,
        configManager: ConfigFileManager = .shared
    ) async -> CopyConflict? {
        let existingServers = await getExistingServers(
            at: destination,
            configManager: configManager
        )

        if let existingServer = existingServers[serverName] {
            return CopyConflict(
                serverName: serverName,
                existingServer: existingServer,
                newServer: server
            )
        }
        return nil
    }

    /// Detects sensitive environment variables in a server config.
    func detectSensitiveEnvVars(server: MCPServer) -> [SensitiveEnvWarning] {
        guard let env = server.env else {
            return []
        }

        var warnings: [SensitiveEnvWarning] = []

        for key in env.keys {
            let lowerKey = key.lowercased()

            if lowerKey.contains("token") {
                warnings.append(SensitiveEnvWarning(
                    key: key,
                    reason: "May contain authentication token"
                ))
            } else if lowerKey.contains("key") || lowerKey.contains("api") {
                warnings.append(SensitiveEnvWarning(
                    key: key,
                    reason: "May contain API key"
                ))
            } else if lowerKey.contains("secret") {
                warnings.append(SensitiveEnvWarning(
                    key: key,
                    reason: "May contain secret value"
                ))
            } else if lowerKey.contains("password") || lowerKey.contains("passwd") {
                warnings.append(SensitiveEnvWarning(
                    key: key,
                    reason: "May contain password"
                ))
            } else if lowerKey.contains("credential") || lowerKey.contains("auth") {
                warnings.append(SensitiveEnvWarning(
                    key: key,
                    reason: "May contain credentials"
                ))
            }
        }

        return warnings
    }

    /// Copies a server to a destination.
    func copyServer(
        name: String,
        server: MCPServer,
        to destination: CopyDestination,
        strategy: ConflictStrategy = .prompt,
        configManager: ConfigFileManager = .shared
    ) async throws -> CopyResult {
        // Check for conflict
        if let conflict = await checkConflict(
            serverName: name,
            server: server,
            destination: destination,
            configManager: configManager
        ) {
            switch strategy {
            case .skip:
                return CopyResult(
                    serverName: name,
                    destination: destination,
                    success: false,
                    message: "Skipped - server already exists",
                    renamed: false,
                    newName: nil
                )

            case .overwrite:
                return try await performCopy(
                    name: name,
                    server: server,
                    to: destination,
                    configManager: configManager
                )

            case .rename:
                let newName = generateUniqueName(
                    baseName: name,
                    existingNames: Set(await getExistingServers(
                        at: destination,
                        configManager: configManager
                    ).keys)
                )
                return try await performCopy(
                    name: newName,
                    server: server,
                    to: destination,
                    configManager: configManager,
                    renamed: true,
                    originalName: name
                )

            case .prompt:
                // Return a result indicating prompt is needed
                return CopyResult(
                    serverName: name,
                    destination: destination,
                    success: false,
                    message: "Conflict detected - server '\(conflict.serverName)' already exists",
                    renamed: false,
                    newName: nil
                )
            }
        }

        // No conflict, perform copy directly
        return try await performCopy(
            name: name,
            server: server,
            to: destination,
            configManager: configManager
        )
    }

    /// Copies a server with a specific conflict resolution.
    func copyServerWithResolution(
        name: String,
        server: MCPServer,
        to destination: CopyDestination,
        resolution: CopyConflict.ConflictResolution,
        configManager: ConfigFileManager = .shared
    ) async throws -> CopyResult {
        switch resolution {
        case .skip:
            return CopyResult(
                serverName: name,
                destination: destination,
                success: false,
                message: "Skipped by user",
                renamed: false,
                newName: nil
            )

        case .overwrite:
            return try await performCopy(
                name: name,
                server: server,
                to: destination,
                configManager: configManager
            )

        case let .rename(newName):
            return try await performCopy(
                name: newName,
                server: server,
                to: destination,
                configManager: configManager,
                renamed: true,
                originalName: name
            )
        }
    }

    // MARK: Private

    private init() {}

    /// Generates a unique name by appending -copy, -copy-2, etc.
    private func generateUniqueName(baseName: String, existingNames: Set<String>) -> String {
        var candidate = "\(baseName)-copy"
        var counter = 2

        while existingNames.contains(candidate) {
            candidate = "\(baseName)-copy-\(counter)"
            counter += 1
        }

        return candidate
    }

    /// Gets existing servers at a destination.
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

    /// Performs the actual copy operation.
    private func performCopy(
        name: String,
        server: MCPServer,
        to destination: CopyDestination,
        configManager: ConfigFileManager,
        renamed: Bool = false,
        originalName: String? = nil
    ) async throws -> CopyResult {
        // Deep copy the server (create new instance)
        let copiedServer = deepCopy(server: server)

        switch destination {
        case .global:
            var config = try await configManager.readGlobalConfig() ?? LegacyConfig()
            if config.mcpServers == nil {
                config.mcpServers = [:]
            }
            config.mcpServers?[name] = copiedServer
            try await configManager.writeGlobalConfig(config)

            Log.general.info("Copied server '\(name)' to global config")

        case let .project(path, _):
            let url = URL(fileURLWithPath: path)
            var mcpConfig = try await configManager.readMCPConfig(for: url)
                ?? MCPConfig(mcpServers: [:])
            if mcpConfig.mcpServers == nil {
                mcpConfig.mcpServers = [:]
            }
            mcpConfig.mcpServers?[name] = copiedServer
            try await configManager.writeMCPConfig(mcpConfig, for: url)

            Log.general.info("Copied server '\(name)' to project at \(path)")
        }

        let message = renamed
            ? "Copied '\(originalName ?? name)' as '\(name)'"
            : "Successfully copied '\(name)'"

        return CopyResult(
            serverName: name,
            destination: destination,
            success: true,
            message: message,
            renamed: renamed,
            newName: renamed ? name : nil
        )
    }

    /// Creates a deep copy of an MCPServer.
    private func deepCopy(server: MCPServer) -> MCPServer {
        // Create a new instance with all the same properties
        // Since MCPServer is a struct, this is a value copy
        // We just need to ensure nested collections are also copied
        var copy = MCPServer()

        // Copy stdio properties
        copy.command = server.command
        if let args = server.args {
            copy.args = Array(args)
        }
        if let env = server.env {
            copy.env = Dictionary(uniqueKeysWithValues: env.map { ($0.key, $0.value) })
        }

        // Copy HTTP properties
        copy.type = server.type
        copy.url = server.url
        if let headers = server.headers {
            copy.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
        }

        // Copy additional properties
        if let additionalProperties = server.additionalProperties {
            copy.additionalProperties = Dictionary(
                uniqueKeysWithValues: additionalProperties.map { ($0.key, $0.value) }
            )
        }

        return copy
    }
}
