import Foundation
import OSLog

// MARK: - PermissionRuleCopyService

/// Service for copying permission rules between configuration scopes.
actor PermissionRuleCopyService {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    static let shared = PermissionRuleCopyService()

    /// Copies a permission rule to the specified destination scope.
    ///
    /// - Parameters:
    ///   - rule: The rule pattern string (e.g., "Bash(npm run *)").
    ///   - type: Whether this is an allow or deny rule.
    ///   - destination: The target config scope.
    ///   - projectPath: The project URL (required for project-level destinations).
    /// - Returns: Whether the rule was actually added (false if duplicate).
    @discardableResult
    func copyRule(
        rule: String,
        type: PermissionType,
        to destination: ConfigSource,
        projectPath: URL? = nil,
        configManager: ConfigFileManager = .shared
    ) async throws -> Bool {
        var settings = try await loadSettings(
            for: destination,
            projectPath: projectPath,
            configManager: configManager
        ) ?? ClaudeSettings()

        var permissions = settings.permissions ?? Permissions()

        switch type {
        case .allow:
            var allow = permissions.allow ?? []
            guard !allow.contains(rule) else {
                Log.general.info("Rule already exists at destination: \(rule)")
                return false
            }
            allow.append(rule)
            permissions.allow = allow

        case .deny:
            var deny = permissions.deny ?? []
            guard !deny.contains(rule) else {
                Log.general.info("Rule already exists at destination: \(rule)")
                return false
            }
            deny.append(rule)
            permissions.deny = deny
        }

        settings.permissions = permissions

        try await self.writeSettings(
            settings,
            for: destination,
            projectPath: projectPath,
            configManager: configManager
        )

        Log.general.info("Copied rule '\(rule)' to \(destination.displayName)")
        return true
    }

    /// Removes a permission rule from the specified scope.
    ///
    /// - Parameters:
    ///   - rule: The rule pattern string.
    ///   - type: Whether this is an allow or deny rule.
    ///   - source: The config scope to remove from.
    ///   - projectPath: The project URL (required for project-level sources).
    func removeRule(
        rule: String,
        type: PermissionType,
        from source: ConfigSource,
        projectPath: URL? = nil,
        configManager: ConfigFileManager = .shared
    ) async throws {
        var settings = try await loadSettings(
            for: source,
            projectPath: projectPath,
            configManager: configManager
        ) ?? ClaudeSettings()

        var permissions = settings.permissions ?? Permissions()

        switch type {
        case .allow:
            permissions.allow?.removeAll { $0 == rule }
            if permissions.allow?.isEmpty == true {
                permissions.allow = nil
            }
        case .deny:
            permissions.deny?.removeAll { $0 == rule }
            if permissions.deny?.isEmpty == true {
                permissions.deny = nil
            }
        }

        if permissions.allow == nil, permissions.deny == nil,
           permissions.additionalProperties == nil
        {
            settings.permissions = nil
        } else {
            settings.permissions = permissions
        }

        try await self.writeSettings(
            settings,
            for: source,
            projectPath: projectPath,
            configManager: configManager
        )

        Log.general.info("Removed rule '\(rule)' from \(source.displayName)")
    }

    /// Checks if a rule already exists at the destination.
    func isDuplicate(
        rule: String,
        type: PermissionType,
        at destination: ConfigSource,
        projectPath: URL? = nil,
        configManager: ConfigFileManager = .shared
    ) async throws -> Bool {
        let settings = try await loadSettings(
            for: destination,
            projectPath: projectPath,
            configManager: configManager
        )
        let existingRules: [String] = switch type {
        case .allow:
            settings?.permissions?.allow ?? []
        case .deny:
            settings?.permissions?.deny ?? []
        }
        return existingRules.contains(rule)
    }

    // MARK: Private

    private func loadSettings(
        for source: ConfigSource,
        projectPath: URL?,
        configManager: ConfigFileManager
    ) async throws -> ClaudeSettings? {
        switch source {
        case .global:
            return try await configManager.readGlobalSettings()
        case .projectShared:
            guard let projectPath else {
                throw FigError.invalidConfiguration(message: "Project path is required for project-level settings")
            }
            return try await configManager.readProjectSettings(for: projectPath)
        case .projectLocal:
            guard let projectPath else {
                throw FigError.invalidConfiguration(message: "Project path is required for project-level settings")
            }
            return try await configManager.readProjectLocalSettings(for: projectPath)
        }
    }

    private func writeSettings(
        _ settings: ClaudeSettings,
        for source: ConfigSource,
        projectPath: URL?,
        configManager: ConfigFileManager
    ) async throws {
        switch source {
        case .global:
            try await configManager.writeGlobalSettings(settings)
        case .projectShared:
            guard let projectPath else {
                throw FigError.invalidConfiguration(message: "Project path is required for project-level settings")
            }
            try await configManager.writeProjectSettings(settings, for: projectPath)
        case .projectLocal:
            guard let projectPath else {
                throw FigError.invalidConfiguration(message: "Project path is required for project-level settings")
            }
            try await configManager.writeProjectLocalSettings(settings, for: projectPath)
        }
    }
}
