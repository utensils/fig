import Foundation
import OSLog

// MARK: - ConfigBundleError

/// Errors that can occur during bundle operations.
enum ConfigBundleError: Error, LocalizedError {
    case invalidBundleFormat
    case unsupportedVersion(Int)
    case exportFailed(underlying: Error)
    case importFailed(underlying: Error)
    case noComponentsSelected
    case projectNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidBundleFormat:
            "Invalid bundle format. The file may be corrupted or not a valid config bundle."
        case let .unsupportedVersion(version):
            "Unsupported bundle version (\(version)). Please update Fig to import this bundle."
        case let .exportFailed(error):
            "Export failed: \(error.localizedDescription)"
        case let .importFailed(error):
            "Import failed: \(error.localizedDescription)"
        case .noComponentsSelected:
            "No components selected for export."
        case let .projectNotFound(path):
            "Project not found at \(path)."
        }
    }
}

// MARK: - ConfigBundleService

/// Service for exporting and importing project configuration bundles.
actor ConfigBundleService {
    // MARK: Internal

    static let shared = ConfigBundleService()

    // MARK: - Export

    /// Exports a project's configuration to a bundle.
    func exportBundle(
        projectPath: URL,
        projectName: String,
        components: Set<ConfigBundleComponent>,
        configManager: ConfigFileManager = .shared
    ) async throws -> ConfigBundle {
        guard !components.isEmpty else {
            throw ConfigBundleError.noComponentsSelected
        }

        var bundle = ConfigBundle(projectName: projectName)

        // Export settings
        if components.contains(.settings) {
            bundle.settings = try await configManager.readProjectSettings(for: projectPath)
        }

        // Export local settings
        if components.contains(.localSettings) {
            bundle.localSettings = try await configManager.readProjectLocalSettings(for: projectPath)
        }

        // Export MCP servers
        if components.contains(.mcpServers) {
            bundle.mcpServers = try await configManager.readMCPConfig(for: projectPath)
        }

        Log.general.info("Exported bundle for '\(projectName)' with \(components.count) components")

        return bundle
    }

    /// Writes a bundle to a file.
    nonisolated func writeBundle(_ bundle: ConfigBundle, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(bundle)
        try data.write(to: url)

        Log.general.info("Wrote bundle to \(url.path)")
    }

    // MARK: - Import

    /// Reads a bundle from a file.
    nonisolated func readBundle(from url: URL) throws -> ConfigBundle {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let bundle = try decoder.decode(ConfigBundle.self, from: data)

        // Validate version
        if bundle.version > ConfigBundle.currentVersion {
            throw ConfigBundleError.unsupportedVersion(bundle.version)
        }

        Log.general.info("Read bundle '\(bundle.projectName)' from \(url.path)")

        return bundle
    }

    /// Detects conflicts when importing a bundle to a project.
    func detectConflicts(
        bundle: ConfigBundle,
        projectPath: URL,
        components: Set<ConfigBundleComponent>,
        configManager: ConfigFileManager = .shared
    ) async -> [ImportConflict] {
        var conflicts: [ImportConflict] = []

        // Check settings conflict
        if components.contains(.settings), bundle.settings != nil {
            if let existing = try? await configManager.readProjectSettings(for: projectPath),
               existing != nil
            {
                conflicts.append(ImportConflict(
                    component: .settings,
                    description: "Project already has settings.json"
                ))
            }
        }

        // Check local settings conflict
        if components.contains(.localSettings), bundle.localSettings != nil {
            if let existing = try? await configManager.readProjectLocalSettings(for: projectPath),
               existing != nil
            {
                conflicts.append(ImportConflict(
                    component: .localSettings,
                    description: "Project already has settings.local.json"
                ))
            }
        }

        // Check MCP servers conflict
        if components.contains(.mcpServers), bundle.mcpServers != nil {
            if let existing = try? await configManager.readMCPConfig(for: projectPath),
               existing.mcpServers?.isEmpty == false
            {
                let existingCount = existing.mcpServers?.count ?? 0
                let importCount = bundle.mcpServers?.mcpServers?.count ?? 0
                conflicts.append(ImportConflict(
                    component: .mcpServers,
                    description: "Project has \(existingCount) servers, import has \(importCount)"
                ))
            }
        }

        return conflicts
    }

    /// Imports a bundle into a project.
    func importBundle(
        _ bundle: ConfigBundle,
        to projectPath: URL,
        components: Set<ConfigBundleComponent>,
        resolutions: [ConfigBundleComponent: ImportConflict.ImportResolution],
        configManager: ConfigFileManager = .shared
    ) async throws -> ImportResult {
        var imported: [ConfigBundleComponent] = []
        var skipped: [ConfigBundleComponent] = []
        var errors: [String] = []

        // Import settings
        if components.contains(.settings), let settings = bundle.settings {
            let resolution = resolutions[.settings] ?? .merge
            if resolution == .skip {
                skipped.append(.settings)
            } else {
                do {
                    try await importSettings(
                        settings,
                        to: projectPath,
                        resolution: resolution,
                        configManager: configManager
                    )
                    imported.append(.settings)
                } catch {
                    errors.append("Settings: \(error.localizedDescription)")
                }
            }
        }

        // Import local settings
        if components.contains(.localSettings), let localSettings = bundle.localSettings {
            let resolution = resolutions[.localSettings] ?? .merge
            if resolution == .skip {
                skipped.append(.localSettings)
            } else {
                do {
                    try await importLocalSettings(
                        localSettings,
                        to: projectPath,
                        resolution: resolution,
                        configManager: configManager
                    )
                    imported.append(.localSettings)
                } catch {
                    errors.append("Local Settings: \(error.localizedDescription)")
                }
            }
        }

        // Import MCP servers
        if components.contains(.mcpServers), let mcpConfig = bundle.mcpServers {
            let resolution = resolutions[.mcpServers] ?? .merge
            if resolution == .skip {
                skipped.append(.mcpServers)
            } else {
                do {
                    try await importMCPServers(
                        mcpConfig,
                        to: projectPath,
                        resolution: resolution,
                        configManager: configManager
                    )
                    imported.append(.mcpServers)
                } catch {
                    errors.append("MCP Servers: \(error.localizedDescription)")
                }
            }
        }

        let success = errors.isEmpty && !imported.isEmpty
        let message: String
        if success {
            message = "Successfully imported \(imported.count) component(s)"
        } else if !errors.isEmpty {
            message = "Import completed with errors"
        } else {
            message = "No components were imported"
        }

        Log.general.info("Import: \(imported.count) imported, \(skipped.count) skipped, \(errors.count) errors")

        return ImportResult(
            success: success,
            message: message,
            componentsImported: imported,
            componentsSkipped: skipped,
            errors: errors
        )
    }

    // MARK: Private

    private init() {}

    // MARK: - Import Helpers

    private func importSettings(
        _ settings: ClaudeSettings,
        to projectPath: URL,
        resolution: ImportConflict.ImportResolution,
        configManager: ConfigFileManager
    ) async throws {
        let existing = try await configManager.readProjectSettings(for: projectPath)

        let finalSettings: ClaudeSettings
        if resolution == .merge, let existing {
            finalSettings = mergeSettings(existing: existing, incoming: settings)
        } else {
            finalSettings = settings
        }

        try await configManager.writeProjectSettings(finalSettings, for: projectPath)
    }

    private func importLocalSettings(
        _ settings: ClaudeSettings,
        to projectPath: URL,
        resolution: ImportConflict.ImportResolution,
        configManager: ConfigFileManager
    ) async throws {
        let existing = try await configManager.readProjectLocalSettings(for: projectPath)

        let finalSettings: ClaudeSettings
        if resolution == .merge, let existing {
            finalSettings = mergeSettings(existing: existing, incoming: settings)
        } else {
            finalSettings = settings
        }

        try await configManager.writeProjectLocalSettings(finalSettings, for: projectPath)
    }

    private func importMCPServers(
        _ config: MCPConfig,
        to projectPath: URL,
        resolution: ImportConflict.ImportResolution,
        configManager: ConfigFileManager
    ) async throws {
        let existing = try await configManager.readMCPConfig(for: projectPath)

        let finalConfig: MCPConfig
        if resolution == .merge, let existing {
            var merged = existing
            if merged.mcpServers == nil {
                merged.mcpServers = [:]
            }
            // Merge servers - incoming overwrites by name
            if let incomingServers = config.mcpServers {
                for (name, server) in incomingServers {
                    merged.mcpServers?[name] = server
                }
            }
            finalConfig = merged
        } else {
            finalConfig = config
        }

        try await configManager.writeMCPConfig(finalConfig, for: projectPath)
    }

    /// Merges two ClaudeSettings instances.
    private func mergeSettings(existing: ClaudeSettings, incoming: ClaudeSettings) -> ClaudeSettings {
        var merged = existing

        // Merge permissions (union of allow/deny)
        if let incomingPermissions = incoming.permissions {
            if merged.permissions == nil {
                merged.permissions = Permissions()
            }

            // Merge allow rules
            if let incomingAllow = incomingPermissions.allow {
                let existingAllow = merged.permissions?.allow ?? []
                let combined = Set(existingAllow).union(Set(incomingAllow))
                merged.permissions?.allow = Array(combined)
            }

            // Merge deny rules
            if let incomingDeny = incomingPermissions.deny {
                let existingDeny = merged.permissions?.deny ?? []
                let combined = Set(existingDeny).union(Set(incomingDeny))
                merged.permissions?.deny = Array(combined)
            }
        }

        // Merge env vars (incoming overwrites)
        if let incomingEnv = incoming.env {
            if merged.env == nil {
                merged.env = [:]
            }
            for (key, value) in incomingEnv {
                merged.env?[key] = value
            }
        }

        // Replace hooks entirely (hooks are complex, safer to replace)
        if incoming.hooks != nil {
            merged.hooks = incoming.hooks
        }

        // Merge disallowed tools
        if let incomingDisallowed = incoming.disallowedTools {
            let existingDisallowed = merged.disallowedTools ?? []
            let combined = Set(existingDisallowed).union(Set(incomingDisallowed))
            merged.disallowedTools = Array(combined)
        }

        // Take incoming attribution if present
        if incoming.attribution != nil {
            merged.attribution = incoming.attribution
        }

        return merged
    }
}
