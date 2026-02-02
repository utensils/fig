import AppKit
import Foundation
import SwiftUI

// MARK: - ConfigExportViewModel

/// View model for the config export flow.
@MainActor
@Observable
final class ConfigExportViewModel {
    // MARK: Lifecycle

    init(projectPath: URL, projectName: String) {
        self.projectPath = projectPath
        self.projectName = projectName

        // Default to all non-sensitive components
        selectedComponents = [.settings, .mcpServers]
    }

    // MARK: Internal

    /// The project path to export from.
    let projectPath: URL

    /// The project name.
    let projectName: String

    /// Selected components to export.
    var selectedComponents: Set<ConfigBundleComponent> = []

    /// Whether to include local settings (requires acknowledgment).
    var includeLocalSettings: Bool {
        get { selectedComponents.contains(.localSettings) }
        set {
            if newValue {
                selectedComponents.insert(.localSettings)
            } else {
                selectedComponents.remove(.localSettings)
            }
        }
    }

    /// Whether the user has acknowledged sensitive data warning.
    var acknowledgedSensitiveData = false

    /// Whether export is in progress.
    private(set) var isExporting = false

    /// Error message if export fails.
    private(set) var errorMessage: String?

    /// Whether export was successful.
    private(set) var exportSuccessful = false

    /// The URL where the bundle was exported.
    private(set) var exportedURL: URL?

    /// Available components based on what exists in the project.
    private(set) var availableComponents: Set<ConfigBundleComponent> = []

    /// Whether the export can proceed.
    var canExport: Bool {
        guard !selectedComponents.isEmpty else { return false }
        guard !isExporting else { return false }

        // Must acknowledge if sensitive data is included
        if includeLocalSettings && !acknowledgedSensitiveData {
            return false
        }

        return true
    }

    /// Loads available components from the project.
    func loadAvailableComponents() async {
        availableComponents = []

        do {
            let configManager = ConfigFileManager.shared

            // Check for settings
            if let settings = try await configManager.readProjectSettings(for: projectPath),
               !isSettingsEmpty(settings)
            {
                availableComponents.insert(.settings)
            }

            // Check for local settings
            if let localSettings = try await configManager.readProjectLocalSettings(for: projectPath),
               !isSettingsEmpty(localSettings)
            {
                availableComponents.insert(.localSettings)
            }

            // Check for MCP config
            if let mcpConfig = try await configManager.readMCPConfig(for: projectPath),
               mcpConfig.mcpServers?.isEmpty == false
            {
                availableComponents.insert(.mcpServers)
            }

            // Update selected to only include available
            selectedComponents = selectedComponents.intersection(availableComponents)

        } catch {
            // Ignore errors, just show what's available
        }
    }

    /// Performs the export with a save panel.
    func performExport() async {
        isExporting = true
        errorMessage = nil
        exportSuccessful = false
        exportedURL = nil

        do {
            // Create bundle
            let bundle = try await ConfigBundleService.shared.exportBundle(
                projectPath: projectPath,
                projectName: projectName,
                components: selectedComponents
            )

            // Show save panel
            let savePanel = NSSavePanel()
            savePanel.title = "Export Configuration"
            savePanel.nameFieldStringValue = "\(projectName).\(ConfigBundle.fileExtension)"
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true

            let response = await savePanel.begin()

            if response == .OK, let url = savePanel.url {
                try ConfigBundleService.shared.writeBundle(bundle, to: url)
                exportedURL = url
                exportSuccessful = true

                NotificationManager.shared.showSuccess(
                    "Export successful",
                    message: "Configuration exported to \(url.lastPathComponent)"
                )
            }

        } catch {
            errorMessage = error.localizedDescription
            NotificationManager.shared.showError(
                "Export failed",
                message: error.localizedDescription
            )
        }

        isExporting = false
    }

    // MARK: Private

    private func isSettingsEmpty(_ settings: ClaudeSettings) -> Bool {
        let hasPermissions = settings.permissions?.allow?.isEmpty == false ||
            settings.permissions?.deny?.isEmpty == false
        let hasEnv = settings.env?.isEmpty == false
        let hasHooks = settings.hooks != nil
        let hasDisallowed = settings.disallowedTools?.isEmpty == false
        let hasAttribution = settings.attribution != nil

        return !hasPermissions && !hasEnv && !hasHooks && !hasDisallowed && !hasAttribution
    }
}
