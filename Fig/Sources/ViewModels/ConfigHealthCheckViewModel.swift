import Foundation
import OSLog

// MARK: - ConfigHealthCheckViewModel

/// View model for running and displaying config health check results.
@MainActor
@Observable
final class ConfigHealthCheckViewModel {
    // MARK: Lifecycle

    init(
        projectPath: URL,
        configManager: ConfigFileManager = .shared,
        healthCheckService: ConfigHealthCheckService = .shared
    ) {
        self.projectPath = projectPath
        self.configManager = configManager
        self.healthCheckService = healthCheckService
    }

    // MARK: Internal

    /// The project path being checked.
    let projectPath: URL

    /// Current findings from the last check run.
    private(set) var findings: [Finding] = []

    /// Whether checks are currently running.
    private(set) var isRunning = false

    /// When checks were last run.
    private(set) var lastRunDate: Date?

    /// Count of findings by severity.
    var severityCounts: [Severity: Int] {
        Dictionary(grouping: findings, by: \.severity)
            .mapValues(\.count)
    }

    /// Findings grouped by severity, ordered from most to least severe.
    var groupedFindings: [(severity: Severity, findings: [Finding])] {
        let grouped = Dictionary(grouping: findings, by: \.severity)
        return Severity.allCases.compactMap { severity in
            guard let items = grouped[severity], !items.isEmpty else {
                return nil
            }
            return (severity, items)
        }
    }

    /// Runs all health checks against the current project configuration.
    func runChecks(
        globalSettings: ClaudeSettings?,
        projectSettings: ClaudeSettings?,
        projectLocalSettings: ClaudeSettings?,
        mcpConfig: MCPConfig?,
        legacyConfig: LegacyConfig?,
        localSettingsExists: Bool,
        mcpConfigExists: Bool
    ) async {
        self.isRunning = true

        // Get global config file size
        let globalConfigSize = self.getGlobalConfigFileSize()

        let context = HealthCheckContext(
            projectPath: self.projectPath,
            globalSettings: globalSettings,
            projectSettings: projectSettings,
            projectLocalSettings: projectLocalSettings,
            mcpConfig: mcpConfig,
            legacyConfig: legacyConfig,
            localSettingsExists: localSettingsExists,
            mcpConfigExists: mcpConfigExists,
            globalConfigFileSize: globalConfigSize
        )

        self.findings = await healthCheckService.runAllChecks(context: context)
        self.lastRunDate = Date()
        self.isRunning = false
    }

    /// Executes the auto-fix for a finding and re-runs checks.
    func executeAutoFix(
        _ finding: Finding,
        globalSettings: ClaudeSettings?,
        projectSettings: ClaudeSettings?,
        projectLocalSettings: ClaudeSettings?,
        mcpConfig: MCPConfig?,
        legacyConfig: LegacyConfig?,
        localSettingsExists: Bool,
        mcpConfigExists: Bool
    ) async {
        guard let autoFix = finding.autoFix else { return }

        do {
            switch autoFix {
            case let .addToDenyList(pattern):
                try await addToDenyList(pattern: pattern)

            case .createLocalSettings:
                try await createLocalSettings()
            }

            NotificationManager.shared.showSuccess(
                "Auto-fix Applied",
                message: autoFix.label
            )

            // Re-run checks to reflect the change
            await runChecks(
                globalSettings: try? await configManager.readGlobalSettings(),
                projectSettings: try? await configManager.readProjectSettings(for: projectPath),
                projectLocalSettings: try? await configManager.readProjectLocalSettings(for: projectPath),
                mcpConfig: mcpConfig,
                legacyConfig: legacyConfig,
                localSettingsExists: await configManager.fileExists(
                    at: configManager.projectLocalSettingsURL(for: projectPath)
                ),
                mcpConfigExists: mcpConfigExists
            )
        } catch {
            Log.general.error("Auto-fix failed: \(error.localizedDescription)")
            NotificationManager.shared.showError(
                "Auto-fix Failed",
                message: error.localizedDescription
            )
        }
    }

    // MARK: Private

    private let configManager: ConfigFileManager
    private let healthCheckService: ConfigHealthCheckService

    /// Gets the file size of `~/.claude.json`.
    private func getGlobalConfigFileSize() -> Int64? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64
        else {
            return nil
        }
        return size
    }

    /// Adds a pattern to the project's deny list in `.claude/settings.json`.
    private func addToDenyList(pattern: String) async throws {
        var settings = try await configManager.readProjectSettings(for: projectPath) ?? ClaudeSettings()

        var permissions = settings.permissions ?? Permissions()
        var deny = permissions.deny ?? []

        guard !deny.contains(pattern) else { return }

        deny.append(pattern)
        permissions.deny = deny
        settings.permissions = permissions

        try await configManager.writeProjectSettings(settings, for: projectPath)
        Log.general.info("Added '\(pattern)' to deny list for \(self.projectPath.lastPathComponent)")
    }

    /// Creates an empty `settings.local.json` file.
    private func createLocalSettings() async throws {
        let settings = ClaudeSettings()
        try await configManager.writeProjectLocalSettings(settings, for: projectPath)
        Log.general.info("Created settings.local.json for \(self.projectPath.lastPathComponent)")
    }
}
