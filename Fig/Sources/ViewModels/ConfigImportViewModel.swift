import AppKit
import Foundation
import SwiftUI

// MARK: - ImportWizardStep

/// Steps in the import wizard.
enum ImportWizardStep: Int, CaseIterable {
    case selectFile
    case selectComponents
    case resolveConflicts
    case preview
    case complete

    // MARK: Internal

    var title: String {
        switch self {
        case .selectFile: "Select File"
        case .selectComponents: "Select Components"
        case .resolveConflicts: "Resolve Conflicts"
        case .preview: "Preview Changes"
        case .complete: "Complete"
        }
    }
}

// MARK: - ConfigImportViewModel

/// View model for the config import wizard.
@MainActor
@Observable
final class ConfigImportViewModel {
    // MARK: Lifecycle

    init(projectPath: URL, projectName: String) {
        self.projectPath = projectPath
        self.projectName = projectName
    }

    // MARK: Internal

    /// The project to import into.
    let projectPath: URL
    let projectName: String

    /// Current wizard step.
    var currentStep: ImportWizardStep = .selectFile

    /// The loaded bundle.
    private(set) var bundle: ConfigBundle?

    /// URL of the selected file.
    private(set) var selectedFileURL: URL?

    /// Selected components to import.
    var selectedComponents: Set<ConfigBundleComponent> = []

    /// Detected conflicts.
    private(set) var conflicts: [ImportConflict] = []

    /// Conflict resolutions chosen by the user.
    var resolutions: [ConfigBundleComponent: ImportConflict.ImportResolution] = [:]

    /// Whether the user has acknowledged sensitive data warning.
    var acknowledgedSensitiveData = false

    /// Whether import is in progress.
    private(set) var isImporting = false

    /// Whether file is being loaded.
    private(set) var isLoading = false

    /// Error message if something fails.
    private(set) var errorMessage: String?

    /// The import result.
    private(set) var importResult: ImportResult?

    /// Available components in the bundle.
    var availableComponents: [ConfigBundleComponent] {
        var components: [ConfigBundleComponent] = []
        if self.bundle?.settings != nil {
            components.append(.settings)
        }
        if self.bundle?.localSettings != nil {
            components.append(.localSettings)
        }
        if self.bundle?.mcpServers != nil {
            components.append(.mcpServers)
        }
        return components
    }

    /// Whether the bundle contains sensitive data.
    var hasSensitiveData: Bool {
        self.bundle?.containsSensitiveData ?? false
    }

    /// Whether the current step can proceed.
    var canProceed: Bool {
        switch self.currentStep {
        case .selectFile:
            return self.bundle != nil
        case .selectComponents:
            guard !self.selectedComponents.isEmpty else {
                return false
            }
            if self.selectedComponents.contains(.localSettings), !self.acknowledgedSensitiveData {
                return false
            }
            return true
        case .resolveConflicts:
            // All conflicts must have resolutions
            return self.conflicts.allSatisfy { self.resolutions[$0.component] != nil }
        case .preview:
            return true
        case .complete:
            return true
        }
    }

    /// Whether we can go back from the current step.
    var canGoBack: Bool {
        self.currentStep != .selectFile && self.currentStep != .complete
    }

    /// Shows the open panel to select a file.
    func selectFile() async {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Configuration Bundle"
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        let response = await openPanel.begin()

        if response == .OK, let url = openPanel.url {
            await self.loadBundle(from: url)
        }
    }

    /// Loads a bundle from a URL.
    func loadBundle(from url: URL) async {
        self.isLoading = true
        self.errorMessage = nil

        do {
            self.bundle = try ConfigBundleService.shared.readBundle(from: url)
            self.selectedFileURL = url

            // Pre-select all available components
            self.selectedComponents = Set(self.availableComponents)

        } catch {
            self.errorMessage = error.localizedDescription
            self.bundle = nil
            self.selectedFileURL = nil
        }

        self.isLoading = false
    }

    /// Advances to the next step.
    func nextStep() async {
        switch self.currentStep {
        case .selectFile:
            self.currentStep = .selectComponents

        case .selectComponents:
            // Detect conflicts
            await self.detectConflicts()
            if self.conflicts.isEmpty {
                self.currentStep = .preview
            } else {
                self.currentStep = .resolveConflicts
            }

        case .resolveConflicts:
            self.currentStep = .preview

        case .preview:
            await self.performImport()
            self.currentStep = .complete

        case .complete:
            break
        }
    }

    /// Goes back to the previous step.
    func previousStep() {
        switch self.currentStep {
        case .selectFile:
            break
        case .selectComponents:
            self.currentStep = .selectFile
        case .resolveConflicts:
            self.currentStep = .selectComponents
        case .preview:
            if self.conflicts.isEmpty {
                self.currentStep = .selectComponents
            } else {
                self.currentStep = .resolveConflicts
            }
        case .complete:
            break
        }
    }

    /// Resets the wizard.
    func reset() {
        self.currentStep = .selectFile
        self.bundle = nil
        self.selectedFileURL = nil
        self.selectedComponents = []
        self.conflicts = []
        self.resolutions = [:]
        self.acknowledgedSensitiveData = false
        self.errorMessage = nil
        self.importResult = nil
    }

    // MARK: Private

    private func detectConflicts() async {
        guard let bundle else {
            return
        }

        self.conflicts = await ConfigBundleService.shared.detectConflicts(
            bundle: bundle,
            projectPath: self.projectPath,
            components: self.selectedComponents
        )

        // Set default resolutions
        for conflict in self.conflicts {
            self.resolutions[conflict.component] = .merge
        }
    }

    private func performImport() async {
        guard let bundle else {
            return
        }

        self.isImporting = true
        self.errorMessage = nil

        do {
            self.importResult = try await ConfigBundleService.shared.importBundle(
                bundle,
                to: self.projectPath,
                components: self.selectedComponents,
                resolutions: self.resolutions
            )

            if let result = importResult, result.success {
                NotificationManager.shared.showSuccess(
                    "Import successful",
                    message: result.message
                )
            } else if let result = importResult, !result.errors.isEmpty {
                NotificationManager.shared.showWarning(
                    "Import completed with errors",
                    message: result.errors.first ?? "Unknown error"
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
}
