import Foundation
import SwiftUI

// MARK: - MCPCopyViewModel

/// View model for the MCP server copy flow.
@MainActor
@Observable
final class MCPCopyViewModel {
    // MARK: Lifecycle

    init(
        serverName: String,
        server: MCPServer,
        sourceDestination: CopyDestination?,
        configManager: ConfigFileManager = .shared
    ) {
        self.serverName = serverName
        self.server = server
        self.sourceDestination = sourceDestination
        self.configManager = configManager
        self.sensitiveWarnings = []

        // Detect sensitive env vars
        Task {
            self.sensitiveWarnings = await MCPServerCopyService.shared
                .detectSensitiveEnvVars(server: server)
        }
    }

    // MARK: Internal

    /// The name of the server being copied.
    let serverName: String

    /// The server configuration being copied.
    let server: MCPServer

    /// The source destination (where the server is being copied from).
    let sourceDestination: CopyDestination?

    /// Available destinations to copy to.
    private(set) var availableDestinations: [CopyDestination] = []

    /// Selected destination.
    var selectedDestination: CopyDestination?

    /// Conflict detected during copy.
    private(set) var conflict: CopyConflict?

    /// Sensitive environment variable warnings.
    private(set) var sensitiveWarnings: [SensitiveEnvWarning]

    /// Whether a copy operation is in progress.
    private(set) var isCopying = false

    /// Whether destinations are being loaded.
    private(set) var isLoadingDestinations = false

    /// The result of the copy operation.
    private(set) var copyResult: CopyResult?

    /// Error message if something goes wrong.
    private(set) var errorMessage: String?

    /// New name for the server (when renaming to avoid conflict).
    var renamedServerName: String = ""

    /// Whether the user has acknowledged sensitive data warning.
    var acknowledgedSensitiveData = false

    /// Whether the copy can proceed.
    var canCopy: Bool {
        guard let destination = selectedDestination else { return false }
        // Can't copy to same location
        if let source = sourceDestination, source == destination { return false }
        // Must acknowledge sensitive data if present
        if !sensitiveWarnings.isEmpty && !acknowledgedSensitiveData { return false }
        return !isCopying
    }

    /// Loads available destinations from projects.
    func loadDestinations(projects: [ProjectEntry]) {
        isLoadingDestinations = true

        var destinations: [CopyDestination] = [.global]

        // Add all projects
        for project in projects {
            if let path = project.path {
                destinations.append(.project(
                    path: path,
                    name: project.name ?? URL(fileURLWithPath: path).lastPathComponent
                ))
            }
        }

        // Filter out source if needed
        if let source = sourceDestination {
            destinations = destinations.filter { $0 != source }
        }

        availableDestinations = destinations
        isLoadingDestinations = false
    }

    /// Checks for conflicts at the selected destination.
    func checkForConflict() async {
        guard let destination = selectedDestination else {
            conflict = nil
            return
        }

        conflict = await MCPServerCopyService.shared.checkConflict(
            serverName: serverName,
            server: server,
            destination: destination,
            configManager: configManager
        )

        // Pre-fill renamed name if conflict exists
        if conflict != nil {
            renamedServerName = serverName + "-copy"
        }
    }

    /// Performs the copy with the specified resolution.
    func performCopy(resolution: CopyConflict.ConflictResolution? = nil) async {
        guard let destination = selectedDestination else { return }

        isCopying = true
        errorMessage = nil
        copyResult = nil

        do {
            let result: CopyResult

            if let conflict, let resolution {
                result = try await MCPServerCopyService.shared.copyServerWithResolution(
                    name: serverName,
                    server: server,
                    to: destination,
                    resolution: resolution,
                    configManager: configManager
                )
            } else if conflict != nil {
                // Conflict exists but no resolution provided - skip
                result = CopyResult(
                    serverName: serverName,
                    destination: destination,
                    success: false,
                    message: "Conflict not resolved",
                    renamed: false,
                    newName: nil
                )
            } else {
                // No conflict, direct copy
                result = try await MCPServerCopyService.shared.copyServer(
                    name: serverName,
                    server: server,
                    to: destination,
                    strategy: .overwrite,
                    configManager: configManager
                )
            }

            copyResult = result

            if result.success {
                // Show success notification
                NotificationManager.shared.showSuccess(
                    "Server copied",
                    message: result.message
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            NotificationManager.shared.showError(
                "Copy failed",
                message: error.localizedDescription
            )
        }

        isCopying = false
    }

    /// Copies with overwrite resolution.
    func copyWithOverwrite() async {
        await performCopy(resolution: .overwrite)
    }

    /// Copies with rename resolution.
    func copyWithRename() async {
        let newName = renamedServerName.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else {
            errorMessage = "Please enter a new name"
            return
        }
        await performCopy(resolution: .rename(newName))
    }

    /// Skips the copy due to conflict.
    func skipCopy() async {
        await performCopy(resolution: .skip)
    }

    // MARK: Private

    private let configManager: ConfigFileManager
}
