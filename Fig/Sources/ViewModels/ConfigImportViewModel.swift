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
        if bundle?.settings != nil { components.append(.settings) }
        if bundle?.localSettings != nil { components.append(.localSettings) }
        if bundle?.mcpServers != nil { components.append(.mcpServers) }
        return components
    }

    /// Whether the bundle contains sensitive data.
    var hasSensitiveData: Bool {
        bundle?.containsSensitiveData ?? false
    }

    /// Whether the current step can proceed.
    var canProceed: Bool {
        switch currentStep {
        case .selectFile:
            return bundle != nil
        case .selectComponents:
            guard !selectedComponents.isEmpty else { return false }
            if selectedComponents.contains(.localSettings) && !acknowledgedSensitiveData {
                return false
            }
            return true
        case .resolveConflicts:
            // All conflicts must have resolutions
            return conflicts.allSatisfy { resolutions[$0.component] != nil }
        case .preview:
            return true
        case .complete:
            return true
        }
    }

    /// Whether we can go back from the current step.
    var canGoBack: Bool {
        currentStep != .selectFile && currentStep != .complete
    }

    // MARK: - Actions

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
            await loadBundle(from: url)
        }
    }

    /// Loads a bundle from a URL.
    func loadBundle(from url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            bundle = try ConfigBundleService.shared.readBundle(from: url)
            selectedFileURL = url

            // Pre-select all available components
            selectedComponents = Set(availableComponents)

        } catch {
            errorMessage = error.localizedDescription
            bundle = nil
            selectedFileURL = nil
        }

        isLoading = false
    }

    /// Advances to the next step.
    func nextStep() async {
        switch currentStep {
        case .selectFile:
            currentStep = .selectComponents

        case .selectComponents:
            // Detect conflicts
            await detectConflicts()
            if conflicts.isEmpty {
                currentStep = .preview
            } else {
                currentStep = .resolveConflicts
            }

        case .resolveConflicts:
            currentStep = .preview

        case .preview:
            await performImport()
            currentStep = .complete

        case .complete:
            break
        }
    }

    /// Goes back to the previous step.
    func previousStep() {
        switch currentStep {
        case .selectFile:
            break
        case .selectComponents:
            currentStep = .selectFile
        case .resolveConflicts:
            currentStep = .selectComponents
        case .preview:
            if conflicts.isEmpty {
                currentStep = .selectComponents
            } else {
                currentStep = .resolveConflicts
            }
        case .complete:
            break
        }
    }

    /// Resets the wizard.
    func reset() {
        currentStep = .selectFile
        bundle = nil
        selectedFileURL = nil
        selectedComponents = []
        conflicts = []
        resolutions = [:]
        acknowledgedSensitiveData = false
        errorMessage = nil
        importResult = nil
    }

    // MARK: Private

    private func detectConflicts() async {
        guard let bundle else { return }

        conflicts = await ConfigBundleService.shared.detectConflicts(
            bundle: bundle,
            projectPath: projectPath,
            components: selectedComponents
        )

        // Set default resolutions
        for conflict in conflicts {
            resolutions[conflict.component] = .merge
        }
    }

    private func performImport() async {
        guard let bundle else { return }

        isImporting = true
        errorMessage = nil

        do {
            importResult = try await ConfigBundleService.shared.importBundle(
                bundle,
                to: projectPath,
                components: selectedComponents,
                resolutions: resolutions
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
            errorMessage = error.localizedDescription
            NotificationManager.shared.showError(
                "Import failed",
                message: error.localizedDescription
            )
        }

        isImporting = false
    }
}
