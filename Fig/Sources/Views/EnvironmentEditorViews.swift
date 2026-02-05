import SwiftUI

// MARK: - EnvironmentVariableEditorView

/// Editor view for managing environment variables.
struct EnvironmentVariableEditorView: View {
    // MARK: Internal

    @Bindable var viewModel: SettingsEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Target selector and add button
                HStack {
                    if !self.viewModel.isGlobalMode {
                        EditingTargetPicker(selection: self.$viewModel.editingTarget)
                    }

                    Spacer()

                    Button {
                        self.showingAddVariable = true
                    } label: {
                        Label("Add Variable", systemImage: "plus")
                    }
                }

                // Known variables info
                DisclosureGroup("Known Variables Reference") {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(KnownEnvironmentVariable.allVariables) { variable in
                            KnownVariableRow(
                                variable: variable,
                                isAdded: self.viewModel.environmentVariables.contains { $0.key == variable.name }
                            ) {
                                self.showingAddVariable = true
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

                // Variables list
                GroupBox {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack {
                            Text("Key")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 200, alignment: .leading)

                            Text("Value")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Actions")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                        Divider()

                        if self.viewModel.environmentVariables.isEmpty {
                            Text("No environment variables configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(self.viewModel.environmentVariables) { envVar in
                                EditableEnvironmentVariableRow(
                                    envVar: envVar,
                                    description: KnownEnvironmentVariable.description(for: envVar.key),
                                    onUpdate: { newKey, newValue in
                                        self.viewModel.updateEnvironmentVariable(
                                            envVar,
                                            newKey: newKey,
                                            newValue: newValue
                                        )
                                    },
                                    onDelete: {
                                        self.viewModel.removeEnvironmentVariable(envVar)
                                    },
                                    isDuplicateKey: { key in
                                        key != envVar.key && self.viewModel.environmentVariables
                                            .contains { $0.key == key }
                                    }
                                )
                                if envVar.id != self.viewModel.environmentVariables.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: self.$showingAddVariable) {
            AddEnvironmentVariableSheet { key, value in
                self.viewModel.addEnvironmentVariable(key: key, value: value)
            } isDuplicateKey: { key in
                self.viewModel.environmentVariables.contains { $0.key == key }
            }
        }
    }

    // MARK: Private

    @State private var showingAddVariable = false
}

// MARK: - KnownVariableRow

/// Row displaying a known environment variable in the reference section.
struct KnownVariableRow: View {
    let variable: KnownEnvironmentVariable
    let isAdded: Bool
    let onAddTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(self.variable.name)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)

                Button {
                    self.onAddTapped()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(self.isAdded)
            }
            Text(self.variable.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - EditableEnvironmentVariableRow

/// A row displaying an editable environment variable.
struct EditableEnvironmentVariableRow: View {
    // MARK: Internal

    let envVar: EditableEnvironmentVariable
    let description: String?
    let onUpdate: (String, String) -> Void
    let onDelete: () -> Void
    let isDuplicateKey: (String) -> Bool

    var body: some View {
        HStack(alignment: .top) {
            if self.isEditing {
                self.editingContent
            } else {
                self.displayContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .confirmationDialog(
            "Delete Variable",
            isPresented: self.$showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                self.onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(self.envVar.key)?")
        }
    }

    // MARK: Private

    @State private var isEditing = false
    @State private var editedKey = ""
    @State private var editedValue = ""
    @State private var isValueVisible = false
    @State private var showingDeleteConfirmation = false

    private var isSensitive: Bool {
        let sensitivePatterns = ["token", "key", "secret", "password", "credential", "api"]
        let lowercaseKey = self.envVar.key.lowercased()
        return sensitivePatterns.contains { lowercaseKey.contains($0) }
    }

    private var canSave: Bool {
        !self.editedKey.isEmpty && !self.isDuplicateKey(self.editedKey)
    }

    @ViewBuilder private var editingContent: some View {
        TextField("Key", text: self.$editedKey)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 200, alignment: .leading)

        TextField("Value", text: self.$editedValue)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity)

        HStack(spacing: 4) {
            Button("Save") {
                self.saveEdit()
            }
            .disabled(!self.canSave)

            Button("Cancel") {
                self.cancelEdit()
            }
        }
        .frame(width: 120)
    }

    @ViewBuilder private var displayContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.envVar.key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 200, alignment: .leading)

        Text("=")
            .foregroundStyle(.secondary)

        Group {
            if self.isValueVisible || !self.isSensitive {
                Text(self.envVar.value)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text(String(repeating: "\u{2022}", count: min(self.envVar.value.count, 20)))
                    .font(.system(.body, design: .monospaced))
            }
        }
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
            if self.isSensitive {
                Button {
                    self.isValueVisible.toggle()
                } label: {
                    Image(systemName: self.isValueVisible ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Button {
                self.startEditing()
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
        .frame(width: 80, alignment: .trailing)
    }

    private func startEditing() {
        self.editedKey = self.envVar.key
        self.editedValue = self.envVar.value
        self.isEditing = true
    }

    private func saveEdit() {
        guard self.canSave else {
            return
        }
        self.onUpdate(self.editedKey, self.editedValue)
        self.isEditing = false
    }

    private func cancelEdit() {
        self.isEditing = false
        self.editedKey = self.envVar.key
        self.editedValue = self.envVar.value
    }
}

// MARK: - AddEnvironmentVariableSheet

/// Sheet for adding a new environment variable.
struct AddEnvironmentVariableSheet: View {
    // MARK: Internal

    let onAdd: (String, String) -> Void
    let isDuplicateKey: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Add Environment Variable")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Key input with autocomplete
            VStack(alignment: .leading, spacing: 4) {
                Text("Key")
                    .font(.headline)

                TextField("VARIABLE_NAME", text: self.$key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                // Autocomplete suggestions
                if !self.key.isEmpty {
                    self.autocompleteView
                }

                // Show description for known variables
                if let knownVar = KnownEnvironmentVariable.allVariables.first(where: { $0.name == key }) {
                    Text(knownVar.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            // Value input
            VStack(alignment: .leading, spacing: 4) {
                Text("Value")
                    .font(.headline)
                TextField("value", text: self.$value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
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

                Button("Add Variable") {
                    self.onAdd(self.key, self.value)
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!self.isValid)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss

    @State private var key = ""
    @State private var value = ""

    private var validationError: String? {
        if self.key.isEmpty {
            return nil // Don't show error until they try to submit
        }
        if self.isDuplicateKey(self.key) {
            return "A variable with this key already exists"
        }
        if self.key.contains(" ") {
            return "Key cannot contain spaces"
        }
        return nil
    }

    private var isValid: Bool {
        !self.key.isEmpty && !self.isDuplicateKey(self.key) && !self.key.contains(" ")
    }

    @ViewBuilder private var autocompleteView: some View {
        let suggestions = KnownEnvironmentVariable.allVariables.filter {
            $0.name.localizedCaseInsensitiveContains(self.key)
        }
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { variable in
                        Button {
                            self.key = variable.name
                        } label: {
                            Text(variable.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview("Environment Variable Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.environmentVariables = [
        EditableEnvironmentVariable(key: "CLAUDE_CODE_MAX_OUTPUT_TOKENS", value: "16384"),
        EditableEnvironmentVariable(key: "API_KEY", value: "sk-1234567890"),
    ]

    return EnvironmentVariableEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 500)
}
