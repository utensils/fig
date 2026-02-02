import Foundation
import OSLog
import SwiftUI

// MARK: - SettingsEditorViewModel

/// View model for editing project settings with undo/redo, dirty tracking, and file watching.
@MainActor
@Observable
final class SettingsEditorViewModel {
    // MARK: Lifecycle

    init(projectPath: String, configManager: ConfigFileManager = .shared) {
        self.projectPath = projectPath
        projectURL = URL(fileURLWithPath: projectPath)
        self.configManager = configManager
    }

    deinit {
        // Clean up file watchers - note: must be called from a Task since deinit is sync
        Task { [configManager, projectURL] in
            let settingsURL = await configManager.projectSettingsURL(for: projectURL)
            let localSettingsURL = await configManager.projectLocalSettingsURL(for: projectURL)
            await configManager.stopWatching(settingsURL)
            await configManager.stopWatching(localSettingsURL)
        }
    }

    // MARK: Internal

    // MARK: - Properties

    let projectPath: String
    let projectURL: URL

    /// Whether data is currently loading.
    private(set) var isLoading = false

    /// Whether there are unsaved changes.
    private(set) var isDirty = false

    /// Whether saving is in progress.
    private(set) var isSaving = false

    /// Current editing target (shared or local).
    var editingTarget: EditingTarget = .projectShared {
        didSet {
            if oldValue != editingTarget {
                loadEditableData()
            }
        }
    }

    // MARK: - Editable Data

    /// Permission rules being edited.
    var permissionRules: [EditablePermissionRule] = []

    /// Environment variables being edited.
    var environmentVariables: [EditableEnvironmentVariable] = []

    /// Attribution settings being edited.
    var attribution: Attribution?

    /// Disallowed tools being edited.
    var disallowedTools: [String] = []

    // MARK: - Original Data (for dirty checking)

    private(set) var originalPermissionRules: [EditablePermissionRule] = []
    private(set) var originalEnvironmentVariables: [EditableEnvironmentVariable] = []
    private(set) var originalAttribution: Attribution?
    private(set) var originalDisallowedTools: [String] = []

    // MARK: - Loaded Settings

    private(set) var projectSettings: ClaudeSettings?
    private(set) var projectLocalSettings: ClaudeSettings?

    // MARK: - Conflict Handling

    private(set) var hasExternalChanges = false
    private(set) var externalChangeURL: URL?

    // MARK: - Computed Properties

    var projectName: String {
        projectURL.lastPathComponent
    }

    var allowRules: [EditablePermissionRule] {
        permissionRules.filter { $0.type == .allow }
    }

    var denyRules: [EditablePermissionRule] {
        permissionRules.filter { $0.type == .deny }
    }

    var canUndo: Bool {
        undoManager?.canUndo ?? false
    }

    var canRedo: Bool {
        undoManager?.canRedo ?? false
    }

    // MARK: - UndoManager

    var undoManager: UndoManager? {
        didSet {
            // Clear undo stack when UndoManager changes
            undoManager?.removeAllActions()
        }
    }

    // MARK: - Loading

    /// Loads settings for the current project.
    func loadSettings() async {
        isLoading = true

        do {
            projectSettings = try await configManager.readProjectSettings(for: projectURL)
            projectLocalSettings = try await configManager.readProjectLocalSettings(for: projectURL)

            loadEditableData()
            startFileWatching()

            Log.general.info("Loaded settings for editing: \(self.projectName)")
        } catch {
            Log.general.error("Failed to load settings for editing: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Reloads settings from disk, discarding local changes.
    func reloadSettings() async {
        await loadSettings()
        isDirty = false
        undoManager?.removeAllActions()
    }

    // MARK: - Saving

    /// Saves the current settings to the target file.
    func save() async throws {
        guard isDirty else { return }

        isSaving = true
        defer { isSaving = false }

        let settings = buildSettings()

        switch editingTarget {
        case .projectShared:
            try await configManager.writeProjectSettings(settings, for: projectURL)
            projectSettings = settings
        case .projectLocal:
            try await configManager.writeProjectLocalSettings(settings, for: projectURL)
            projectLocalSettings = settings
        }

        // Update originals
        updateOriginals()
        isDirty = false
        undoManager?.removeAllActions()

        Log.general.info("Saved settings to \(self.editingTarget.label)")
    }

    // MARK: - Permission Rule Editing

    /// Adds a new permission rule.
    func addPermissionRule(_ rule: String, type: PermissionType) {
        let newRule = EditablePermissionRule(rule: rule, type: type)
        permissionRules.append(newRule)
        markDirty()

        registerUndo(actionName: "Add Rule") { [weak self] in
            self?.removePermissionRuleWithoutUndo(newRule)
        }
    }

    /// Removes a permission rule.
    func removePermissionRule(_ rule: EditablePermissionRule) {
        guard let index = permissionRules.firstIndex(of: rule) else { return }

        permissionRules.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Rule") { [weak self] in
            self?.permissionRules.insert(rule, at: min(index, self?.permissionRules.count ?? 0))
            self?.markDirty()
        }
    }

    /// Updates a permission rule.
    func updatePermissionRule(_ rule: EditablePermissionRule, newRule: String, newType: PermissionType) {
        guard let index = permissionRules.firstIndex(of: rule) else { return }

        let oldRule = rule.rule
        let oldType = rule.type

        permissionRules[index].rule = newRule
        permissionRules[index].type = newType
        markDirty()

        registerUndo(actionName: "Update Rule") { [weak self] in
            if let idx = self?.permissionRules.firstIndex(where: { $0.id == rule.id }) {
                self?.permissionRules[idx].rule = oldRule
                self?.permissionRules[idx].type = oldType
                self?.markDirty()
            }
        }
    }

    /// Moves permission rules for reordering.
    func movePermissionRules(type: PermissionType, from source: IndexSet, to destination: Int) {
        var rules = type == .allow ? allowRules : denyRules
        rules.move(fromOffsets: source, toOffset: destination)

        // Rebuild full permission rules list
        let otherRules = permissionRules.filter { $0.type != type }
        permissionRules = otherRules + rules
        markDirty()

        // Register undo
        let originalRules = permissionRules
        registerUndo(actionName: "Reorder Rules") { [weak self] in
            self?.permissionRules = originalRules
            self?.markDirty()
        }
    }

    /// Applies a permission preset.
    func applyPreset(_ preset: PermissionPreset) {
        let originalRules = permissionRules

        for (rule, type) in preset.rules {
            let isDuplicate = permissionRules.contains { $0.rule == rule && $0.type == type }
            if !isDuplicate {
                permissionRules.append(EditablePermissionRule(rule: rule, type: type))
            }
        }

        if permissionRules != originalRules {
            markDirty()

            registerUndo(actionName: "Apply Preset") { [weak self] in
                self?.permissionRules = originalRules
                self?.markDirty()
            }
        }
    }

    // MARK: - Environment Variable Editing

    /// Adds a new environment variable.
    func addEnvironmentVariable(key: String, value: String) {
        // Check for duplicate keys
        guard !environmentVariables.contains(where: { $0.key == key }) else { return }

        let newVar = EditableEnvironmentVariable(key: key, value: value)
        environmentVariables.append(newVar)
        markDirty()

        registerUndo(actionName: "Add Variable") { [weak self] in
            self?.environmentVariables.removeAll { $0.id == newVar.id }
            self?.markDirty()
        }
    }

    /// Removes an environment variable.
    func removeEnvironmentVariable(_ envVar: EditableEnvironmentVariable) {
        guard let index = environmentVariables.firstIndex(of: envVar) else { return }

        environmentVariables.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Variable") { [weak self] in
            self?.environmentVariables.insert(envVar, at: min(index, self?.environmentVariables.count ?? 0))
            self?.markDirty()
        }
    }

    /// Updates an environment variable.
    func updateEnvironmentVariable(_ envVar: EditableEnvironmentVariable, newKey: String, newValue: String) {
        guard let index = environmentVariables.firstIndex(of: envVar) else { return }

        // Check for duplicate keys (excluding current)
        if newKey != envVar.key, environmentVariables.contains(where: { $0.key == newKey }) {
            return
        }

        let oldKey = envVar.key
        let oldValue = envVar.value

        environmentVariables[index].key = newKey
        environmentVariables[index].value = newValue
        markDirty()

        registerUndo(actionName: "Update Variable") { [weak self] in
            if let idx = self?.environmentVariables.firstIndex(where: { $0.id == envVar.id }) {
                self?.environmentVariables[idx].key = oldKey
                self?.environmentVariables[idx].value = oldValue
                self?.markDirty()
            }
        }
    }

    // MARK: - Attribution Editing

    /// Updates attribution settings.
    func updateAttribution(commits: Bool?, pullRequests: Bool?) {
        let oldAttribution = attribution

        if commits == nil, pullRequests == nil {
            attribution = nil
        } else {
            attribution = Attribution(commits: commits, pullRequests: pullRequests)
        }

        markDirty()

        registerUndo(actionName: "Update Attribution") { [weak self] in
            self?.attribution = oldAttribution
            self?.markDirty()
        }
    }

    // MARK: - Disallowed Tools Editing

    /// Adds a disallowed tool.
    func addDisallowedTool(_ tool: String) {
        guard !tool.isEmpty, !disallowedTools.contains(tool) else { return }

        disallowedTools.append(tool)
        markDirty()

        registerUndo(actionName: "Add Disallowed Tool") { [weak self] in
            self?.disallowedTools.removeAll { $0 == tool }
            self?.markDirty()
        }
    }

    /// Removes a disallowed tool.
    func removeDisallowedTool(_ tool: String) {
        guard let index = disallowedTools.firstIndex(of: tool) else { return }

        disallowedTools.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Disallowed Tool") { [weak self] in
            self?.disallowedTools.insert(tool, at: min(index, self?.disallowedTools.count ?? 0))
            self?.markDirty()
        }
    }

    // MARK: - Conflict Resolution

    /// Acknowledges external changes and chooses resolution.
    func resolveConflict(_ resolution: ConflictResolution) async {
        switch resolution {
        case .keepLocal:
            hasExternalChanges = false
            externalChangeURL = nil

        case .useExternal:
            await reloadSettings()
            hasExternalChanges = false
            externalChangeURL = nil

        case .viewDiff:
            // The view will handle showing the diff
            break
        }
    }

    /// Dismisses the external changes notification without action.
    func dismissExternalChanges() {
        hasExternalChanges = false
        externalChangeURL = nil
    }

    // MARK: - Validation

    /// Validates a permission rule pattern.
    func validatePermissionRule(_ rule: String) -> (isValid: Bool, error: String?) {
        // Empty rule is invalid
        if rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "Rule cannot be empty")
        }

        // Check for basic pattern format
        // Valid formats: "ToolName" or "ToolName(pattern)"
        let pattern = #"^[A-Za-z]+(\([^)]*\))?$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(rule.startIndex..., in: rule)

        if regex?.firstMatch(in: rule, options: [], range: range) == nil {
            return (false, "Invalid format. Use 'Tool' or 'Tool(pattern)'")
        }

        return (true, nil)
    }

    /// Checks if a permission rule would be a duplicate.
    func isRuleDuplicate(_ rule: String, type: PermissionType, excluding: EditablePermissionRule? = nil) -> Bool {
        permissionRules.contains { existing in
            existing.rule == rule && existing.type == type && existing.id != excluding?.id
        }
    }

    // MARK: Private

    private let configManager: ConfigFileManager

    private func loadEditableData() {
        let settings: ClaudeSettings? = editingTarget == .projectShared ? projectSettings : projectLocalSettings

        // Load permission rules
        var rules: [EditablePermissionRule] = []
        if let allow = settings?.permissions?.allow {
            rules.append(contentsOf: allow.map { EditablePermissionRule(rule: $0, type: .allow) })
        }
        if let deny = settings?.permissions?.deny {
            rules.append(contentsOf: deny.map { EditablePermissionRule(rule: $0, type: .deny) })
        }
        permissionRules = rules
        originalPermissionRules = rules

        // Load environment variables
        if let env = settings?.env {
            environmentVariables = env.sorted { $0.key < $1.key }
                .map { EditableEnvironmentVariable(key: $0.key, value: $0.value) }
        } else {
            environmentVariables = []
        }
        originalEnvironmentVariables = environmentVariables

        // Load attribution
        attribution = settings?.attribution
        originalAttribution = attribution

        // Load disallowed tools
        disallowedTools = settings?.disallowedTools ?? []
        originalDisallowedTools = disallowedTools

        isDirty = false
    }

    private func updateOriginals() {
        originalPermissionRules = permissionRules
        originalEnvironmentVariables = environmentVariables
        originalAttribution = attribution
        originalDisallowedTools = disallowedTools
    }

    private func buildSettings() -> ClaudeSettings {
        let existingSettings: ClaudeSettings? = editingTarget == .projectShared
            ? projectSettings
            : projectLocalSettings

        let allowRules = permissionRules.filter { $0.type == .allow }.map(\.rule)
        let denyRules = permissionRules.filter { $0.type == .deny }.map(\.rule)

        let permissions = (allowRules.isEmpty && denyRules.isEmpty) ? nil : Permissions(
            allow: allowRules.isEmpty ? nil : allowRules,
            deny: denyRules.isEmpty ? nil : denyRules
        )

        let env: [String: String]? = environmentVariables.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: environmentVariables.map { ($0.key, $0.value) })

        return ClaudeSettings(
            permissions: permissions,
            env: env,
            hooks: existingSettings?.hooks,
            disallowedTools: disallowedTools.isEmpty ? nil : disallowedTools,
            attribution: attribution,
            additionalProperties: existingSettings?.additionalProperties
        )
    }

    private func markDirty() {
        isDirty = checkDirty()
    }

    private func checkDirty() -> Bool {
        permissionRules != originalPermissionRules ||
            environmentVariables != originalEnvironmentVariables ||
            attribution != originalAttribution ||
            disallowedTools != originalDisallowedTools
    }

    private func registerUndo(actionName: String, handler: @escaping () -> Void) {
        undoManager?.registerUndo(withTarget: self) { _ in
            handler()
        }
        undoManager?.setActionName(actionName)
    }

    private func removePermissionRuleWithoutUndo(_ rule: EditablePermissionRule) {
        permissionRules.removeAll { $0.id == rule.id }
        markDirty()
    }

    private func startFileWatching() {
        Task {
            let settingsURL = await configManager.projectSettingsURL(for: projectURL)
            let localSettingsURL = await configManager.projectLocalSettingsURL(for: projectURL)

            await configManager.startWatching(settingsURL) { [weak self] url in
                Task { @MainActor in
                    self?.handleExternalChange(url: url)
                }
            }

            await configManager.startWatching(localSettingsURL) { [weak self] url in
                Task { @MainActor in
                    self?.handleExternalChange(url: url)
                }
            }
        }
    }

    private func handleExternalChange(url: URL) {
        // Only show conflict if we have unsaved changes
        if isDirty {
            hasExternalChanges = true
            externalChangeURL = url
            Log.general.info("External changes detected with unsaved edits: \(url.lastPathComponent)")
        } else {
            // Auto-reload if no local changes
            Task {
                await reloadSettings()
                NotificationManager.shared.showInfo(
                    "Settings Reloaded",
                    message: "\(url.lastPathComponent) was modified externally"
                )
            }
        }
    }
}
