import Foundation

// MARK: - MCPPasteViewModel

/// View model for the paste/import MCP servers flow.
@MainActor
@Observable
final class MCPPasteViewModel: Identifiable {
    // MARK: Lifecycle

    init(
        currentProject: CopyDestination? = nil,
        sharingService: MCPSharingService = .shared
    ) {
        self.currentProject = currentProject
        self.sharingService = sharingService
        self.selectedDestination = currentProject
    }

    // MARK: Internal

    /// The selected destination for import.
    var selectedDestination: CopyDestination?

    /// The conflict strategy to use.
    var conflictStrategy: ConflictStrategy = .rename

    /// Whether import is in progress.
    private(set) var isImporting = false

    /// Parsed servers from the JSON text.
    private(set) var parsedServers: [String: MCPServer]?

    /// Error from parsing.
    private(set) var parseError: String?

    /// The import result after a successful import.
    private(set) var importResult: BulkImportResult?

    /// Error from import.
    private(set) var errorMessage: String?

    /// Available destinations for import.
    private(set) var availableDestinations: [CopyDestination] = []

    /// The JSON text entered by the user.
    var jsonText: String = "" {
        didSet {
            self.parseJSON()
        }
    }

    /// Number of parsed servers.
    var serverCount: Int {
        self.parsedServers?.count ?? 0
    }

    /// Sorted server names from parsed JSON.
    var serverNames: [String] {
        self.parsedServers?.keys.sorted() ?? []
    }

    /// Whether the import can proceed.
    var canImport: Bool {
        guard let servers = parsedServers, !servers.isEmpty else {
            return false
        }
        guard self.selectedDestination != nil else {
            return false
        }
        guard !self.isImporting else {
            return false
        }
        return true
    }

    /// Whether the import completed successfully.
    var importSucceeded: Bool {
        self.importResult?.totalImported ?? 0 > 0
    }

    /// Loads available destinations from projects.
    func loadDestinations(projects: [ProjectEntry]) {
        var destinations: [CopyDestination] = [.global]

        for project in projects {
            if let path = project.path, let name = project.name {
                destinations.append(.project(path: path, name: name))
            }
        }

        self.availableDestinations = destinations
    }

    /// Reads JSON from the system clipboard and sets it as the input text.
    func loadFromClipboard() async {
        if let clipboardText = sharingService.readFromClipboard() {
            self.jsonText = clipboardText
        }
    }

    /// Performs the import operation.
    func performImport() async {
        guard let servers = parsedServers, !servers.isEmpty,
              let destination = selectedDestination
        else {
            return
        }

        self.isImporting = true
        self.errorMessage = nil
        self.importResult = nil

        do {
            let result = try await sharingService.importServers(
                servers,
                to: destination,
                strategy: self.conflictStrategy
            )

            self.importResult = result

            if result.totalImported > 0 {
                NotificationManager.shared.showSuccess(
                    "Import successful",
                    message: "\(result.totalImported) server(s) imported"
                )
            } else if !result.skipped.isEmpty {
                NotificationManager.shared.showInfo(
                    "Import skipped",
                    message: "All servers were skipped due to conflicts"
                )
            }

        } catch {
            self.errorMessage = error.localizedDescription
            NotificationManager.shared.showError(
                "Import failed",
                message: error.localizedDescription
            )
        }

        self.isImporting = false
    }

    // MARK: Private

    /// The current project destination (for pre-selection).
    private let currentProject: CopyDestination?

    private let sharingService: MCPSharingService

    private func parseJSON() {
        self.parsedServers = nil
        self.parseError = nil

        let trimmed = self.jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        Task {
            do {
                self.parsedServers = try await self.sharingService.parseServersFromJSON(trimmed)
                self.parseError = nil
            } catch {
                self.parsedServers = nil
                self.parseError = error.localizedDescription
            }
        }
    }
}
