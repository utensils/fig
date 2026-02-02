import Foundation
import OSLog

// MARK: - MCPServerEditorViewModel

/// View model for the MCP server add/edit form.
@MainActor
@Observable
final class MCPServerEditorViewModel {
    // MARK: Lifecycle

    init(
        formData: MCPServerFormData = MCPServerFormData(),
        projectPath: URL? = nil,
        configManager: ConfigFileManager = .shared,
        notificationManager: NotificationManager = .shared
    ) {
        self.formData = formData
        self.projectPath = projectPath
        self.configManager = configManager
        self.notificationManager = notificationManager
    }

    // MARK: Public

    /// The form data being edited.
    var formData: MCPServerFormData

    /// Validation errors to display.
    private(set) var validationErrors: [MCPValidationError] = []

    /// Whether a save operation is in progress.
    private(set) var isSaving = false

    /// The project path for project-scoped servers.
    let projectPath: URL?

    /// Whether we're editing an existing server.
    var isEditing: Bool {
        formData.isEditing
    }

    /// Title for the form.
    var formTitle: String {
        isEditing ? "Edit MCP Server" : "Add MCP Server"
    }

    /// Whether the form can be saved.
    var canSave: Bool {
        validationErrors.isEmpty && !isSaving
    }

    // MARK: - Factory Methods

    /// Creates a view model for adding a new server.
    static func forAdding(
        projectPath: URL?,
        defaultScope: MCPServerScope = .project
    ) -> MCPServerEditorViewModel {
        let formData = MCPServerFormData()
        formData.scope = defaultScope
        return MCPServerEditorViewModel(formData: formData, projectPath: projectPath)
    }

    /// Creates a view model for editing an existing server.
    static func forEditing(
        name: String,
        server: MCPServer,
        scope: MCPServerScope,
        projectPath: URL?
    ) -> MCPServerEditorViewModel {
        let formData = MCPServerFormData.from(name: name, server: server, scope: scope)
        return MCPServerEditorViewModel(formData: formData, projectPath: projectPath)
    }

    // MARK: - Validation

    /// Validates the current form data.
    func validate() {
        Task {
            let existingNames = await getExistingServerNames()
            validationErrors = formData.validate(existingNames: existingNames)
        }
    }

    /// Returns the validation error for a specific field.
    func error(for field: String) -> MCPValidationError? {
        validationErrors.first { $0.field == field }
    }

    // MARK: - Save

    /// Saves the server configuration.
    /// - Returns: `true` if save was successful, `false` otherwise.
    func save() async -> Bool {
        // Validate first
        let existingNames = await getExistingServerNames()
        validationErrors = formData.validate(existingNames: existingNames)

        guard validationErrors.isEmpty else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let server = formData.toMCPServer()
            let serverName = formData.name.trimmingCharacters(in: .whitespaces)

            switch formData.scope {
            case .project:
                try await saveToProject(name: serverName, server: server)
            case .global:
                try await saveToGlobal(name: serverName, server: server)
            }

            let action = isEditing ? "updated" : "added"
            notificationManager.showSuccess("Server \(action)", message: "'\(serverName)' saved successfully")
            Log.general.info("MCP server \(action): \(serverName)")

            return true
        } catch {
            notificationManager.showError(error)
            Log.general.error("Failed to save MCP server: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Import

    /// Imports configuration from JSON.
    func importFromJSON(_ json: String) -> Bool {
        do {
            try formData.parseFromJSON(json)
            validate()
            return true
        } catch {
            notificationManager.showError("Import failed", message: error.localizedDescription)
            return false
        }
    }

    /// Imports configuration from a CLI command.
    func importFromCLICommand(_ command: String) -> Bool {
        do {
            try formData.parseFromCLICommand(command)
            validate()
            return true
        } catch {
            notificationManager.showError("Import failed", message: error.localizedDescription)
            return false
        }
    }

    // MARK: Private

    private let configManager: ConfigFileManager
    private let notificationManager: NotificationManager

    private func getExistingServerNames() async -> Set<String> {
        var names = Set<String>()

        do {
            switch formData.scope {
            case .project:
                if let projectPath {
                    let config = try await configManager.readMCPConfig(for: projectPath)
                    if let servers = config?.mcpServers {
                        names.formUnion(servers.keys)
                    }
                }
            case .global:
                let config = try await configManager.readGlobalConfig()
                if let servers = config?.mcpServers {
                    names.formUnion(servers.keys)
                }
            }
        } catch {
            Log.general.warning("Failed to read existing server names: \(error.localizedDescription)")
        }

        // If editing, remove the original name so we can keep the same name
        if let originalName = formData.originalName {
            names.remove(originalName)
        }

        return names
    }

    private func saveToProject(name: String, server: MCPServer) async throws {
        guard let projectPath else {
            throw FigError.configurationError(message: "No project path specified for project-scoped server")
        }

        var config = try await configManager.readMCPConfig(for: projectPath) ?? MCPConfig()

        // If editing and name changed, remove old entry
        if isEditing, let originalName = formData.originalName, originalName != name {
            config.mcpServers?.removeValue(forKey: originalName)
        }

        if config.mcpServers == nil {
            config.mcpServers = [:]
        }
        config.mcpServers?[name] = server

        try await configManager.writeMCPConfig(config, for: projectPath)
    }

    private func saveToGlobal(name: String, server: MCPServer) async throws {
        var config = try await configManager.readGlobalConfig() ?? LegacyConfig()

        // If editing and name changed, remove old entry
        if isEditing, let originalName = formData.originalName, originalName != name {
            config.mcpServers?.removeValue(forKey: originalName)
        }

        if config.mcpServers == nil {
            config.mcpServers = [:]
        }
        config.mcpServers?[name] = server

        try await configManager.writeGlobalConfig(config)
    }
}
