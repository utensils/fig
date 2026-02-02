import SwiftUI

// MARK: - PermissionRuleEditorView

/// Editor view for managing permission rules.
struct PermissionRuleEditorView: View {
    // MARK: Internal

    @Bindable var viewModel: SettingsEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Target selector and quick-add
                HStack {
                    EditingTargetPicker(selection: $viewModel.editingTarget)

                    Spacer()

                    Menu {
                        ForEach(PermissionPreset.allPresets) { preset in
                            Button {
                                viewModel.applyPreset(preset)
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
                                showingAddAllowRule = true
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        if viewModel.allowRules.isEmpty {
                            Text("No allow rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(viewModel.allowRules) { rule in
                                EditablePermissionRuleRow(
                                    rule: rule,
                                    onUpdate: { newRule, newType in
                                        viewModel.updatePermissionRule(rule, newRule: newRule, newType: newType)
                                    },
                                    onDelete: {
                                        viewModel.removePermissionRule(rule)
                                    },
                                    validateRule: viewModel.validatePermissionRule,
                                    isDuplicate: { ruleStr, type in
                                        viewModel.isRuleDuplicate(ruleStr, type: type, excluding: rule)
                                    }
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
                                showingAddDenyRule = true
                            } label: {
                                Label("Add Rule", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        if viewModel.denyRules.isEmpty {
                            Text("No deny rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(viewModel.denyRules) { rule in
                                EditablePermissionRuleRow(
                                    rule: rule,
                                    onUpdate: { newRule, newType in
                                        viewModel.updatePermissionRule(rule, newRule: newRule, newType: newType)
                                    },
                                    onDelete: {
                                        viewModel.removePermissionRule(rule)
                                    },
                                    validateRule: viewModel.validatePermissionRule,
                                    isDuplicate: { ruleStr, type in
                                        viewModel.isRuleDuplicate(ruleStr, type: type, excluding: rule)
                                    }
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
        .sheet(isPresented: $showingAddAllowRule) {
            AddPermissionRuleSheet(type: .allow) { rule in
                viewModel.addPermissionRule(rule, type: .allow)
            } validateRule: { rule in
                viewModel.validatePermissionRule(rule)
            } isDuplicate: { rule in
                viewModel.isRuleDuplicate(rule, type: .allow)
            }
        }
        .sheet(isPresented: $showingAddDenyRule) {
            AddPermissionRuleSheet(type: .deny) { rule in
                viewModel.addPermissionRule(rule, type: .deny)
            } validateRule: { rule in
                viewModel.validatePermissionRule(rule)
            } isDuplicate: { rule in
                viewModel.isRuleDuplicate(rule, type: .deny)
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

    var body: some View {
        HStack {
            Image(systemName: rule.type.icon)
                .foregroundStyle(rule.type == .allow ? .green : .red)
                .frame(width: 20)

            if isEditing {
                TextField("Rule pattern", text: $editedRule)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        saveEdit()
                    }

                Button("Save") {
                    saveEdit()
                }
                .disabled(!canSave)

                Button("Cancel") {
                    isEditing = false
                    editedRule = rule.rule
                }
            } else {
                Text(rule.rule)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    isEditing = true
                    editedRule = rule.rule
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    showingDeleteConfirmation = true
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
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this rule?\n\(rule.rule)")
        }
    }

    // MARK: Private

    @State private var isEditing = false
    @State private var editedRule = ""
    @State private var showingDeleteConfirmation = false

    private var canSave: Bool {
        let validation = validateRule(editedRule)
        return validation.isValid && !isDuplicate(editedRule, rule.type)
    }

    private func saveEdit() {
        guard canSave else { return }
        onUpdate(editedRule, rule.type)
        isEditing = false
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
                Image(systemName: type == .allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(type == .allow ? .green : .red)
                    .font(.title2)
                Text("Add \(type == .allow ? "Allow" : "Deny") Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Tool type selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Tool Type")
                    .font(.headline)
                Picker("Tool Type", selection: $selectedTool) {
                    ForEach(ToolType.allCases) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.menu)
            }

            // Custom tool name (if custom selected)
            if selectedTool == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Tool Name")
                        .font(.headline)
                    TextField("ToolName", text: $customToolName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Pattern input
            VStack(alignment: .leading, spacing: 4) {
                Text("Pattern (optional)")
                    .font(.headline)
                TextField(selectedTool.placeholder, text: $pattern)
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
                    Image(systemName: type.icon)
                        .foregroundStyle(type == .allow ? .green : .red)
                    Text(generatedRule)
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
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Rule") {
                    onAdd(generatedRule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
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
        selectedTool == .custom ? customToolName : selectedTool.rawValue
    }

    private var generatedRule: String {
        if pattern.isEmpty {
            return toolName
        }
        return "\(toolName)(\(pattern))"
    }

    private var validationError: String? {
        if selectedTool == .custom, customToolName.isEmpty {
            return "Enter a custom tool name"
        }
        if isDuplicate(generatedRule) {
            return "This rule already exists"
        }
        let validation = validateRule(generatedRule)
        return validation.error
    }

    private var isValid: Bool {
        validationError == nil && !toolName.isEmpty
    }
}

#Preview("Permission Rule Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.permissionRules = [
        EditablePermissionRule(rule: "Bash(npm run *)", type: .allow),
        EditablePermissionRule(rule: "Read(src/**)", type: .allow),
        EditablePermissionRule(rule: "Read(.env)", type: .deny)
    ]

    return PermissionRuleEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 500)
}
