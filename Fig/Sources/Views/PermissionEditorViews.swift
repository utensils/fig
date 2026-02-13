import SwiftUI

// MARK: - PermissionRuleEditorView

/// Editor view for managing permission rules.
struct PermissionRuleEditorView: View {
    // MARK: Internal

    @Bindable var viewModel: SettingsEditorViewModel

    /// Callback when a rule should be promoted to global settings (only in project mode).
    var onPromoteToGlobal: ((String, PermissionType) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Target selector and quick-add
                HStack {
                    if !self.viewModel.isGlobalMode {
                        EditingTargetPicker(selection: self.$viewModel.editingTarget)
                    }

                    Spacer()

                    Menu {
                        ForEach(PermissionPreset.allPresets) { preset in
                            Button {
                                self.viewModel.applyPreset(preset)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(preset.name)
                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label("Quick Add", systemImage: "bolt.fill")
                    }
                }

                // Allow rules section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Allow Rules", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)

                            Spacer()

                            Button {
                                self.showingAddAllowRule = true
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        if self.viewModel.allowRules.isEmpty {
                            Text("No allow rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(self.viewModel.allowRules) { rule in
                                EditablePermissionRuleRow(
                                    rule: rule,
                                    onUpdate: { newRule, newType in
                                        self.viewModel.updatePermissionRule(rule, newRule: newRule, newType: newType)
                                    },
                                    onDelete: {
                                        self.viewModel.removePermissionRule(rule)
                                    },
                                    validateRule: self.viewModel.validatePermissionRule,
                                    isDuplicate: { ruleStr, type in
                                        self.viewModel.isRuleDuplicate(ruleStr, type: type, excluding: rule)
                                    },
                                    onPromoteToGlobal: self.onPromoteToGlobal != nil ? {
                                        self.onPromoteToGlobal?(rule.rule, .allow)
                                    } : nil
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Deny rules section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Deny Rules", systemImage: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)

                            Spacer()

                            Button {
                                self.showingAddDenyRule = true
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        if self.viewModel.denyRules.isEmpty {
                            Text("No deny rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(self.viewModel.denyRules) { rule in
                                EditablePermissionRuleRow(
                                    rule: rule,
                                    onUpdate: { newRule, newType in
                                        self.viewModel.updatePermissionRule(rule, newRule: newRule, newType: newType)
                                    },
                                    onDelete: {
                                        self.viewModel.removePermissionRule(rule)
                                    },
                                    validateRule: self.viewModel.validatePermissionRule,
                                    isDuplicate: { ruleStr, type in
                                        self.viewModel.isRuleDuplicate(ruleStr, type: type, excluding: rule)
                                    },
                                    onPromoteToGlobal: self.onPromoteToGlobal != nil ? {
                                        self.onPromoteToGlobal?(rule.rule, .deny)
                                    } : nil
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: self.$showingAddAllowRule) {
            AddPermissionRuleSheet(type: .allow) { rule in
                self.viewModel.addPermissionRule(rule, type: .allow)
            } validateRule: { rule in
                self.viewModel.validatePermissionRule(rule)
            } isDuplicate: { rule in
                self.viewModel.isRuleDuplicate(rule, type: .allow)
            }
        }
        .sheet(isPresented: self.$showingAddDenyRule) {
            AddPermissionRuleSheet(type: .deny) { rule in
                self.viewModel.addPermissionRule(rule, type: .deny)
            } validateRule: { rule in
                self.viewModel.validatePermissionRule(rule)
            } isDuplicate: { rule in
                self.viewModel.isRuleDuplicate(rule, type: .deny)
            }
        }
    }

    // MARK: Private

    @State private var showingAddAllowRule = false
    @State private var showingAddDenyRule = false
}

// MARK: - EditablePermissionRuleRow

/// A row displaying an editable permission rule.
struct EditablePermissionRuleRow: View {
    // MARK: Internal

    let rule: EditablePermissionRule
    let onUpdate: (String, PermissionType) -> Void
    let onDelete: () -> Void
    let validateRule: (String) -> (isValid: Bool, error: String?)
    let isDuplicate: (String, PermissionType) -> Bool
    var onPromoteToGlobal: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: self.rule.type.icon)
                .foregroundStyle(self.rule.type == .allow ? .green : .red)
                .frame(width: 20)

            if self.isEditing {
                TextField("Rule pattern", text: self.$editedRule)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        self.saveEdit()
                    }

                Button("Save") {
                    self.saveEdit()
                }
                .disabled(!self.canSave)

                Button("Cancel") {
                    self.isEditing = false
                    self.editedRule = self.rule.rule
                }
            } else {
                Text(self.rule.rule)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    self.isEditing = true
                    self.editedRule = self.rule.rule
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    self.showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
        .confirmationDialog(
            "Delete Rule",
            isPresented: self.$showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                self.onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this rule?\n\(self.rule.rule)")
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.rule.rule, forType: .string)
            } label: {
                Label("Copy Rule", systemImage: "doc.on.doc")
            }

            if let onPromoteToGlobal {
                Divider()

                Button {
                    onPromoteToGlobal()
                } label: {
                    Label("Promote to Global", systemImage: "arrow.up.to.line")
                }
            }

            Divider()

            Button(role: .destructive) {
                self.showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Private

    @State private var isEditing = false
    @State private var editedRule = ""
    @State private var showingDeleteConfirmation = false

    private var canSave: Bool {
        let validation = self.validateRule(self.editedRule)
        return validation.isValid && !self.isDuplicate(self.editedRule, self.rule.type)
    }

    private func saveEdit() {
        guard self.canSave else {
            return
        }
        self.onUpdate(self.editedRule, self.rule.type)
        self.isEditing = false
    }
}

// MARK: - AddPermissionRuleSheet

/// Sheet for adding a new permission rule with a builder UI.
struct AddPermissionRuleSheet: View {
    // MARK: Lifecycle

    init(
        type: PermissionType,
        onAdd: @escaping (String) -> Void,
        validateRule: @escaping (String) -> (isValid: Bool, error: String?),
        isDuplicate: @escaping (String) -> Bool
    ) {
        self.type = type
        self.onAdd = onAdd
        self.validateRule = validateRule
        self.isDuplicate = isDuplicate
    }

    // MARK: Internal

    let type: PermissionType
    let onAdd: (String) -> Void
    let validateRule: (String) -> (isValid: Bool, error: String?)
    let isDuplicate: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: self.type == .allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(self.type == .allow ? .green : .red)
                    .font(.title2)
                Text("Add \(self.type == .allow ? "Allow" : "Deny") Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Tool type selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Tool Type")
                    .font(.headline)
                Picker("Tool Type", selection: self.$selectedTool) {
                    ForEach(ToolType.allCases) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.menu)
            }

            // Custom tool name (if custom selected)
            if self.selectedTool == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Tool Name")
                        .font(.headline)
                    TextField("ToolName", text: self.$customToolName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Pattern input
            VStack(alignment: .leading, spacing: 4) {
                Text("Pattern (optional)")
                    .font(.headline)
                TextField(self.selectedTool.placeholder, text: self.$pattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Use * for wildcard, ** for recursive match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.headline)
                HStack {
                    Image(systemName: self.type.icon)
                        .foregroundStyle(self.type == .allow ? .green : .red)
                    Text(self.generatedRule)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
            }

            // Validation error
            if let error = validationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Rule") {
                    self.onAdd(self.generatedRule)
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!self.isValid)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedTool: ToolType = .bash
    @State private var customToolName = ""
    @State private var pattern = ""

    private var toolName: String {
        self.selectedTool == .custom ? self.customToolName : self.selectedTool.rawValue
    }

    private var generatedRule: String {
        if self.pattern.isEmpty {
            return self.toolName
        }
        return "\(self.toolName)(\(self.pattern))"
    }

    private var validationError: String? {
        if self.selectedTool == .custom, self.customToolName.isEmpty {
            return "Enter a custom tool name"
        }
        if self.isDuplicate(self.generatedRule) {
            return "This rule already exists"
        }
        let validation = self.validateRule(self.generatedRule)
        return validation.error
    }

    private var isValid: Bool {
        self.validationError == nil && !self.toolName.isEmpty
    }
}

// MARK: - RulePromotionInfo

/// Info about a rule being promoted, used by the shared promote-to-global modifier.
struct RulePromotionInfo {
    let rule: String
    let type: PermissionType
}

// MARK: - PromoteToGlobalModifier

/// Shared view modifier that provides the promote-to-global confirmation alert and action.
struct PromoteToGlobalModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var ruleToPromote: RulePromotionInfo?

    let projectURL: URL?
    var onComplete: (() async -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                "Promote to Global",
                isPresented: self.$isPresented,
                presenting: self.ruleToPromote
            ) { ruleInfo in
                Button("Cancel", role: .cancel) {}
                Button("Promote") {
                    Task {
                        do {
                            let added = try await PermissionRuleCopyService.shared.copyRule(
                                rule: ruleInfo.rule,
                                type: ruleInfo.type,
                                to: .global,
                                projectPath: self.projectURL
                            )
                            if added {
                                NotificationManager.shared.showSuccess(
                                    "Rule Promoted",
                                    message: "Rule added to global settings"
                                )
                            } else {
                                NotificationManager.shared.showInfo(
                                    "Rule Already Exists",
                                    message: "This rule already exists in global settings"
                                )
                            }
                            await self.onComplete?()
                        } catch {
                            NotificationManager.shared.showError(error)
                        }
                    }
                }
            } message: { ruleInfo in
                Text("Copy '\(ruleInfo.rule)' to global settings?\nThis will make it apply to all projects.")
            }
    }
}

extension View {
    /// Adds promote-to-global alert handling for permission rules.
    func promoteToGlobalAlert(
        isPresented: Binding<Bool>,
        ruleToPromote: Binding<RulePromotionInfo?>,
        projectURL: URL?,
        onComplete: (() async -> Void)? = nil
    ) -> some View {
        modifier(PromoteToGlobalModifier(
            isPresented: isPresented,
            ruleToPromote: ruleToPromote,
            projectURL: projectURL,
            onComplete: onComplete
        ))
    }
}

#Preview("Permission Rule Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.permissionRules = [
        EditablePermissionRule(rule: "Bash(npm run *)", type: .allow),
        EditablePermissionRule(rule: "Read(src/**)", type: .allow),
        EditablePermissionRule(rule: "Read(.env)", type: .deny),
    ]

    return PermissionRuleEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 500)
}
