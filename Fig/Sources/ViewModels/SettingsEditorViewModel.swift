import Foundation
import OSLog
import SwiftUI

// swiftlint:disable file_length

// MARK: - SettingsEditorViewModel

/// View model for editing settings (global or project-level) with undo/redo, dirty tracking, and file watching.
@MainActor
@Observable
final class SettingsEditorViewModel { // swiftlint:disable:this type_body_length
    // MARK: Lifecycle

    /// Creates a view model for editing project settings.
    init(projectPath: String, configManager: ConfigFileManager = .shared) {
        self.projectPath = projectPath
        projectURL = URL(fileURLWithPath: projectPath)
        self.configManager = configManager
        editingTarget = .projectShared
    }

    /// Creates a view model for editing global settings.
    static func forGlobal(configManager: ConfigFileManager = .shared) -> SettingsEditorViewModel {
        SettingsEditorViewModel(configManager: configManager)
    }

    /// Private initializer for global mode.
    private init(configManager: ConfigFileManager) {
        self.projectPath = nil
        self.projectURL = nil
        self.configManager = configManager
        self.editingTarget = .global
    }

    deinit {
        // Clean up file watchers - note: must be called from a Task since deinit is sync
        if let projectURL {
            Task { [configManager, projectURL] in
                let settingsURL = await configManager.projectSettingsURL(for: projectURL)
                let localSettingsURL = await configManager.projectLocalSettingsURL(for: projectURL)
                await configManager.stopWatching(settingsURL)
                await configManager.stopWatching(localSettingsURL)
            }
        } else {
            Task { [configManager] in
                let globalURL = await configManager.globalSettingsURL
                await configManager.stopWatching(globalURL)
            }
        }
    }

    // MARK: Internal

    // MARK: - Properties

    /// Project path, nil when editing global settings.
    let projectPath: String?

    /// Project URL, nil when editing global settings.
    let projectURL: URL?

    /// Whether this view model is editing global settings.
    var isGlobalMode: Bool {
        projectURL == nil
    }

    /// Whether data is currently loading.
    private(set) var isLoading = false

    /// Whether there are unsaved changes.
    private(set) var isDirty = false

    /// Whether saving is in progress.
    private(set) var isSaving = false

    /// Current editing target.
    var editingTarget: EditingTarget = .projectShared {
        didSet {
            if oldValue != editingTarget {
                loadEditableData()
            }
        }
    }

    /// Whether switching target requires confirmation due to unsaved changes.
    var pendingTargetSwitch: EditingTarget?

    /// Attempts to switch target, returning true if switch can proceed immediately.
    func switchTarget(to newTarget: EditingTarget) -> Bool {
        if isDirty {
            pendingTargetSwitch = newTarget
            return false
        }
        editingTarget = newTarget
        return true
    }

    /// Confirms pending target switch, discarding changes.
    func confirmTargetSwitch() {
        guard let newTarget = pendingTargetSwitch else { return }
        pendingTargetSwitch = nil
        editingTarget = newTarget
    }

    /// Cancels pending target switch.
    func cancelTargetSwitch() {
        pendingTargetSwitch = nil
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

    /// Hook groups being edited, keyed by event name.
    var hookGroups: [String: [EditableHookGroup]] = [:]

    // MARK: - Original Data (for dirty checking)

    private(set) var originalPermissionRules: [EditablePermissionRule] = []
    private(set) var originalEnvironmentVariables: [EditableEnvironmentVariable] = []
    private(set) var originalAttribution: Attribution?
    private(set) var originalDisallowedTools: [String] = []
    private(set) var originalHookGroups: [String: [EditableHookGroup]] = [:]

    // MARK: - Loaded Settings

    private(set) var globalSettings: ClaudeSettings?
    private(set) var projectSettings: ClaudeSettings?
    private(set) var projectLocalSettings: ClaudeSettings?

    // MARK: - Conflict Handling

    private(set) var hasExternalChanges = false
    private(set) var externalChangeURL: URL?

    // MARK: - Computed Properties

    var displayName: String {
        if isGlobalMode {
            return "Global Settings"
        }
        return projectURL?.lastPathComponent ?? "Unknown"
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

    /// Loads settings for editing.
    func loadSettings() async {
        isLoading = true

        do {
            if isGlobalMode {
                globalSettings = try await configManager.readGlobalSettings()
            } else if let projectURL {
                projectSettings = try await configManager.readProjectSettings(for: projectURL)
                projectLocalSettings = try await configManager.readProjectLocalSettings(for: projectURL)
            }

            loadEditableData()
            startFileWatching()

            Log.general.info("Loaded settings for editing: \(self.displayName)")
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
        case .global:
            try await configManager.writeGlobalSettings(settings)
            globalSettings = settings
        case .projectShared:
            guard let projectURL else { return }
            try await configManager.writeProjectSettings(settings, for: projectURL)
            projectSettings = settings
        case .projectLocal:
            guard let projectURL else { return }
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
            guard let self else { return }
            self.permissionRules.removeAll { $0.id == newRule.id }
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Add Rule") { [weak self] in
                self?.permissionRules.append(newRule)
                self?.markDirty()
            }
        }
    }

    /// Removes a permission rule.
    func removePermissionRule(_ rule: EditablePermissionRule) {
        guard let index = permissionRules.firstIndex(of: rule) else { return }

        permissionRules.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Rule") { [weak self] in
            guard let self else { return }
            let insertIndex = min(index, self.permissionRules.count)
            self.permissionRules.insert(rule, at: insertIndex)
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Remove Rule") { [weak self] in
                self?.permissionRules.removeAll { $0.id == rule.id }
                self?.markDirty()
            }
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
            guard let self, let idx = self.permissionRules.firstIndex(where: { $0.id == rule.id }) else { return }
            self.permissionRules[idx].rule = oldRule
            self.permissionRules[idx].type = oldType
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Update Rule") { [weak self] in
                guard let self, let idx = self.permissionRules.firstIndex(where: { $0.id == rule.id }) else { return }
                self.permissionRules[idx].rule = newRule
                self.permissionRules[idx].type = newType
                self.markDirty()
            }
        }
    }

    /// Moves permission rules for reordering.
    func movePermissionRules(type: PermissionType, from source: IndexSet, to destination: Int) {
        // Capture pre-move state for undo
        let previousRules = permissionRules

        var rules = type == .allow ? allowRules : denyRules
        rules.move(fromOffsets: source, toOffset: destination)

        // Rebuild full permission rules list
        let otherRules = permissionRules.filter { $0.type != type }
        let newRules = otherRules + rules
        permissionRules = newRules
        markDirty()

        // Register undo with pre-move state
        registerUndo(actionName: "Reorder Rules") { [weak self] in
            guard let self else { return }
            self.permissionRules = previousRules
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Reorder Rules") { [weak self] in
                self?.permissionRules = newRules
                self?.markDirty()
            }
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

        let newRules = permissionRules
        if newRules != originalRules {
            markDirty()

            registerUndo(actionName: "Apply Preset") { [weak self] in
                guard let self else { return }
                self.permissionRules = originalRules
                self.markDirty()
                // Register redo
                self.registerUndo(actionName: "Apply Preset") { [weak self] in
                    self?.permissionRules = newRules
                    self?.markDirty()
                }
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
            guard let self else { return }
            self.environmentVariables.removeAll { $0.id == newVar.id }
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Add Variable") { [weak self] in
                self?.environmentVariables.append(newVar)
                self?.markDirty()
            }
        }
    }

    /// Removes an environment variable.
    func removeEnvironmentVariable(_ envVar: EditableEnvironmentVariable) {
        guard let index = environmentVariables.firstIndex(of: envVar) else { return }

        environmentVariables.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Variable") { [weak self] in
            guard let self else { return }
            let insertIndex = min(index, self.environmentVariables.count)
            self.environmentVariables.insert(envVar, at: insertIndex)
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Remove Variable") { [weak self] in
                self?.environmentVariables.removeAll { $0.id == envVar.id }
                self?.markDirty()
            }
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
            guard let self, let idx = self.environmentVariables.firstIndex(where: { $0.id == envVar.id }) else { return }
            self.environmentVariables[idx].key = oldKey
            self.environmentVariables[idx].value = oldValue
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Update Variable") { [weak self] in
                guard let self, let idx = self.environmentVariables.firstIndex(where: { $0.id == envVar.id }) else { return }
                self.environmentVariables[idx].key = newKey
                self.environmentVariables[idx].value = newValue
                self.markDirty()
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

        let newAttribution = attribution
        markDirty()

        registerUndo(actionName: "Update Attribution") { [weak self] in
            guard let self else { return }
            self.attribution = oldAttribution
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Update Attribution") { [weak self] in
                self?.attribution = newAttribution
                self?.markDirty()
            }
        }
    }

    // MARK: - Disallowed Tools Editing

    /// Adds a disallowed tool.
    func addDisallowedTool(_ tool: String) {
        guard !tool.isEmpty, !disallowedTools.contains(tool) else { return }

        disallowedTools.append(tool)
        markDirty()

        registerUndo(actionName: "Add Disallowed Tool") { [weak self] in
            guard let self else { return }
            self.disallowedTools.removeAll { $0 == tool }
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Add Disallowed Tool") { [weak self] in
                self?.disallowedTools.append(tool)
                self?.markDirty()
            }
        }
    }

    /// Removes a disallowed tool.
    func removeDisallowedTool(_ tool: String) {
        guard let index = disallowedTools.firstIndex(of: tool) else { return }

        disallowedTools.remove(at: index)
        markDirty()

        registerUndo(actionName: "Remove Disallowed Tool") { [weak self] in
            guard let self else { return }
            let insertIndex = min(index, self.disallowedTools.count)
            self.disallowedTools.insert(tool, at: insertIndex)
            self.markDirty()
            // Register redo
            self.registerUndo(actionName: "Remove Disallowed Tool") { [weak self] in
                self?.disallowedTools.removeAll { $0 == tool }
                self?.markDirty()
            }
        }
    }

    // MARK: - Hook Group Editing

    /// Adds a new hook group for a specific event.
    func addHookGroup(event: String, matcher: String, commands: [String]) {
        let hooks = commands.map { EditableHookDefinition(type: "command", command: $0) }
        let newGroup = EditableHookGroup(matcher: matcher, hooks: hooks)

        var groups = hookGroups[event] ?? []
        groups.append(newGroup)
        hookGroups[event] = groups
        markDirty()

        registerUndo(actionName: "Add Hook Group") { [weak self] in
            guard let self else { return }
            self.hookGroups[event]?.removeAll { $0.id == newGroup.id }
            if self.hookGroups[event]?.isEmpty == true { self.hookGroups[event] = nil }
            self.markDirty()
            self.registerUndo(actionName: "Add Hook Group") { [weak self] in
                var groups = self?.hookGroups[event] ?? []
                groups.append(newGroup)
                self?.hookGroups[event] = groups
                self?.markDirty()
            }
        }
    }

    /// Removes a hook group from a specific event.
    func removeHookGroup(event: String, group: EditableHookGroup) {
        guard let index = hookGroups[event]?.firstIndex(of: group) else { return }

        hookGroups[event]?.remove(at: index)
        if hookGroups[event]?.isEmpty == true { hookGroups[event] = nil }
        markDirty()

        registerUndo(actionName: "Remove Hook Group") { [weak self] in
            guard let self else { return }
            var groups = self.hookGroups[event] ?? []
            let insertIndex = min(index, groups.count)
            groups.insert(group, at: insertIndex)
            self.hookGroups[event] = groups
            self.markDirty()
            self.registerUndo(actionName: "Remove Hook Group") { [weak self] in
                self?.hookGroups[event]?.removeAll { $0.id == group.id }
                if self?.hookGroups[event]?.isEmpty == true { self?.hookGroups[event] = nil }
                self?.markDirty()
            }
        }
    }

    /// Updates a hook group's matcher pattern.
    func updateHookGroupMatcher(event: String, group: EditableHookGroup, newMatcher: String) {
        guard let index = hookGroups[event]?.firstIndex(where: { $0.id == group.id }) else { return }

        let oldMatcher = group.matcher
        hookGroups[event]?[index].matcher = newMatcher
        markDirty()

        registerUndo(actionName: "Update Matcher") { [weak self] in
            guard let self,
                  let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == group.id })
            else { return }
            self.hookGroups[event]?[idx].matcher = oldMatcher
            self.markDirty()
            self.registerUndo(actionName: "Update Matcher") { [weak self] in
                guard let self,
                      let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == group.id })
                else { return }
                self.hookGroups[event]?[idx].matcher = newMatcher
                self.markDirty()
            }
        }
    }

    /// Adds a hook definition to a group.
    func addHookDefinition(event: String, groupID: UUID, command: String) {
        guard let groupIndex = hookGroups[event]?.firstIndex(where: { $0.id == groupID }) else { return }

        let newHook = EditableHookDefinition(type: "command", command: command)
        hookGroups[event]?[groupIndex].hooks.append(newHook)
        markDirty()

        registerUndo(actionName: "Add Hook") { [weak self] in
            guard let self,
                  let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
            else { return }
            self.hookGroups[event]?[idx].hooks.removeAll { $0.id == newHook.id }
            self.markDirty()
            self.registerUndo(actionName: "Add Hook") { [weak self] in
                guard let self,
                      let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
                else { return }
                self.hookGroups[event]?[idx].hooks.append(newHook)
                self.markDirty()
            }
        }
    }

    /// Removes a hook definition from a group.
    func removeHookDefinition(event: String, groupID: UUID, hook: EditableHookDefinition) {
        guard let groupIndex = hookGroups[event]?.firstIndex(where: { $0.id == groupID }),
              let hookIndex = hookGroups[event]?[groupIndex].hooks.firstIndex(of: hook)
        else { return }

        hookGroups[event]?[groupIndex].hooks.remove(at: hookIndex)
        markDirty()

        registerUndo(actionName: "Remove Hook") { [weak self] in
            guard let self,
                  let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
            else { return }
            let insertIndex = min(hookIndex, self.hookGroups[event]![idx].hooks.count)
            self.hookGroups[event]?[idx].hooks.insert(hook, at: insertIndex)
            self.markDirty()
            self.registerUndo(actionName: "Remove Hook") { [weak self] in
                guard let self,
                      let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
                else { return }
                self.hookGroups[event]?[idx].hooks.removeAll { $0.id == hook.id }
                self.markDirty()
            }
        }
    }

    /// Updates a hook definition's command.
    func updateHookDefinition(
        event: String,
        groupID: UUID,
        hook: EditableHookDefinition,
        newCommand: String
    ) {
        guard let groupIndex = hookGroups[event]?.firstIndex(where: { $0.id == groupID }),
              let hookIndex = hookGroups[event]?[groupIndex].hooks
              .firstIndex(where: { $0.id == hook.id })
        else { return }

        let oldCommand = hook.command
        hookGroups[event]?[groupIndex].hooks[hookIndex].command = newCommand
        markDirty()

        registerUndo(actionName: "Update Hook") { [weak self] in
            guard let self,
                  let gIdx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID }),
                  let hIdx = self.hookGroups[event]?[gIdx].hooks
                  .firstIndex(where: { $0.id == hook.id })
            else { return }
            self.hookGroups[event]?[gIdx].hooks[hIdx].command = oldCommand
            self.markDirty()
            self.registerUndo(actionName: "Update Hook") { [weak self] in
                guard let self,
                      let gIdx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID }),
                      let hIdx = self.hookGroups[event]?[gIdx].hooks
                      .firstIndex(where: { $0.id == hook.id })
                else { return }
                self.hookGroups[event]?[gIdx].hooks[hIdx].command = newCommand
                self.markDirty()
            }
        }
    }

    /// Moves hook definitions within a group for reordering.
    func moveHookDefinition(event: String, groupID: UUID, from source: Int, direction: Int) {
        guard let groupIndex = hookGroups[event]?.firstIndex(where: { $0.id == groupID })
        else { return }

        let destination = source + direction
        let hooks = hookGroups[event]![groupIndex].hooks
        guard destination >= 0, destination < hooks.count else { return }

        let previousHooks = hooks
        hookGroups[event]?[groupIndex].hooks.swapAt(source, destination)
        let newHooks = hookGroups[event]![groupIndex].hooks
        markDirty()

        registerUndo(actionName: "Reorder Hooks") { [weak self] in
            guard let self,
                  let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
            else { return }
            self.hookGroups[event]?[idx].hooks = previousHooks
            self.markDirty()
            self.registerUndo(actionName: "Reorder Hooks") { [weak self] in
                guard let self,
                      let idx = self.hookGroups[event]?.firstIndex(where: { $0.id == groupID })
                else { return }
                self.hookGroups[event]?[idx].hooks = newHooks
                self.markDirty()
            }
        }
    }

    /// Moves a hook group within an event for reordering.
    func moveHookGroup(event: String, from source: Int, direction: Int) {
        guard let groups = hookGroups[event] else { return }

        let destination = source + direction
        guard destination >= 0, destination < groups.count else { return }

        let previousGroups = groups
        hookGroups[event]?.swapAt(source, destination)
        let newGroups = hookGroups[event]!
        markDirty()

        registerUndo(actionName: "Reorder Hook Groups") { [weak self] in
            guard let self else { return }
            self.hookGroups[event] = previousGroups
            self.markDirty()
            self.registerUndo(actionName: "Reorder Hook Groups") { [weak self] in
                self?.hookGroups[event] = newGroups
                self?.markDirty()
            }
        }
    }

    /// Applies a hook template.
    func applyHookTemplate(_ template: HookTemplate) {
        addHookGroup(
            event: template.event.rawValue,
            matcher: template.matcher ?? "",
            commands: template.commands
        )
        undoManager?.setActionName("Apply Template")
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
        // Tool names can contain letters, digits, underscores, dots, and dashes
        let pattern = #"^[A-Za-z][A-Za-z0-9_.-]*(?:\([^)]*\))?$"#
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
        let settings: ClaudeSettings?
        switch editingTarget {
        case .global:
            settings = globalSettings
        case .projectShared:
            settings = projectSettings
        case .projectLocal:
            settings = projectLocalSettings
        }

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

        // Load hook groups
        var loadedHookGroups: [String: [EditableHookGroup]] = [:]
        if let hooks = settings?.hooks {
            for (event, groups) in hooks {
                loadedHookGroups[event] = groups.map { EditableHookGroup(from: $0) }
            }
        }
        hookGroups = loadedHookGroups
        originalHookGroups = loadedHookGroups

        isDirty = false
    }

    private func updateOriginals() {
        originalPermissionRules = permissionRules
        originalEnvironmentVariables = environmentVariables
        originalAttribution = attribution
        originalDisallowedTools = disallowedTools
        originalHookGroups = hookGroups
    }

    private func buildSettings() -> ClaudeSettings {
        let existingSettings: ClaudeSettings?
        switch editingTarget {
        case .global:
            existingSettings = globalSettings
        case .projectShared:
            existingSettings = projectSettings
        case .projectLocal:
            existingSettings = projectLocalSettings
        }

        let allowRules = permissionRules.filter { $0.type == .allow }.map(\.rule)
        let denyRules = permissionRules.filter { $0.type == .deny }.map(\.rule)

        let permissions = (allowRules.isEmpty && denyRules.isEmpty) ? nil : Permissions(
            allow: allowRules.isEmpty ? nil : allowRules,
            deny: denyRules.isEmpty ? nil : denyRules
        )

        let env: [String: String]? = environmentVariables.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: environmentVariables.map { ($0.key, $0.value) })

        // Build hooks dictionary from editable data
        let builtHooks: [String: [HookGroup]]?
        if hookGroups.isEmpty {
            builtHooks = nil
        } else {
            var result: [String: [HookGroup]] = [:]
            for (event, editableGroups) in hookGroups {
                let groups = editableGroups.map { $0.toHookGroup() }
                if !groups.isEmpty {
                    result[event] = groups
                }
            }
            builtHooks = result.isEmpty ? nil : result
        }

        return ClaudeSettings(
            permissions: permissions,
            env: env,
            hooks: builtHooks,
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
            disallowedTools != originalDisallowedTools ||
            hookGroups != originalHookGroups
    }

    private func registerUndo(actionName: String, handler: @escaping () -> Void) {
        undoManager?.registerUndo(withTarget: self) { _ in
            handler()
        }
        undoManager?.setActionName(actionName)
    }

    private func startFileWatching() {
        Task {
            if isGlobalMode {
                let globalURL = await configManager.globalSettingsURL
                await configManager.startWatching(globalURL) { [weak self] url in
                    Task { @MainActor in
                        self?.handleExternalChange(url: url)
                    }
                }
            } else if let projectURL {
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
    }

    private func handleExternalChange(url: URL) {
        // Only show conflict if we have unsaved changes
        if isDirty {
            hasExternalChanges = true
            externalChangeURL = url
            Log.general.info("External changes detected with unsaved edits: \(url.lastPathComponent)")
        } else {
            // Auto-reload if no local changes
            Task { @MainActor in
                await reloadSettings()
                NotificationManager.shared.showInfo(
                    "Settings Reloaded",
                    message: "\(url.lastPathComponent) was modified externally"
                )
            }
        }
    }
}
