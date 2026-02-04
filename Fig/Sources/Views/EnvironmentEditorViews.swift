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
                    if !viewModel.isGlobalMode {
                        EditingTargetPicker(selection: $viewModel.editingTarget)
                    }

                    Spacer()

                    Button {
                        showingAddVariable = true
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
                                isAdded: viewModel.environmentVariables.contains { $0.key == variable.name }
                            ) {
                                showingAddVariable = true
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

                        if viewModel.environmentVariables.isEmpty {
                            Text("No environment variables configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(viewModel.environmentVariables) { envVar in
                                EditableEnvironmentVariableRow(
                                    envVar: envVar,
                                    description: KnownEnvironmentVariable.description(for: envVar.key),
                                    onUpdate: { newKey, newValue in
                                        viewModel.updateEnvironmentVariable(
                                            envVar,
                                            newKey: newKey,
                                            newValue: newValue
                                        )
                                    },
                                    onDelete: {
                                        viewModel.removeEnvironmentVariable(envVar)
                                    },
                                    isDuplicateKey: { key in
                                        key != envVar.key && viewModel.environmentVariables.contains { $0.key == key }
                                    }
                                )
                                if envVar.id != viewModel.environmentVariables.last?.id {
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
        .sheet(isPresented: $showingAddVariable) {
            AddEnvironmentVariableSheet { key, value in
                viewModel.addEnvironmentVariable(key: key, value: value)
            } isDuplicateKey: { key in
                viewModel.environmentVariables.contains { $0.key == key }
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
                Text(variable.name)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)

                Button {
                    onAddTapped()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(isAdded)
            }
            Text(variable.description)
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
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .confirmationDialog(
            "Delete Variable",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(envVar.key)?")
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
        let lowercaseKey = envVar.key.lowercased()
        return sensitivePatterns.contains { lowercaseKey.contains($0) }
    }

    private var canSave: Bool {
        !editedKey.isEmpty && !isDuplicateKey(editedKey)
    }

    @ViewBuilder private var editingContent: some View {
        TextField("Key", text: $editedKey)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 200, alignment: .leading)

        TextField("Value", text: $editedValue)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity)

        HStack(spacing: 4) {
            Button("Save") {
                saveEdit()
            }
            .disabled(!canSave)

            Button("Cancel") {
                cancelEdit()
            }
        }
        .frame(width: 120)
    }

    @ViewBuilder private var displayContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(envVar.key)
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
            if isValueVisible || !isSensitive {
                Text(envVar.value)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text(String(repeating: "\u{2022}", count: min(envVar.value.count, 20)))
                    .font(.system(.body, design: .monospaced))
            }
        }
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
            if isSensitive {
                Button {
                    isValueVisible.toggle()
                } label: {
                    Image(systemName: isValueVisible ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Button {
                startEditing()
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
        .frame(width: 80, alignment: .trailing)
    }

    private func startEditing() {
        editedKey = envVar.key
        editedValue = envVar.value
        isEditing = true
    }

    private func saveEdit() {
        guard canSave else { return }
        onUpdate(editedKey, editedValue)
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        editedKey = envVar.key
        editedValue = envVar.value
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

                TextField("VARIABLE_NAME", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                // Autocomplete suggestions
                if !key.isEmpty {
                    autocompleteView
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
                TextField("value", text: $value)
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
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Variable") {
                    onAdd(key, value)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
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

    @ViewBuilder private var autocompleteView: some View {
        let suggestions = KnownEnvironmentVariable.allVariables.filter {
            $0.name.localizedCaseInsensitiveContains(key)
        }
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { variable in
                        Button {
                            key = variable.name
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

    private var validationError: String? {
        if key.isEmpty {
            return nil // Don't show error until they try to submit
        }
        if isDuplicateKey(key) {
            return "A variable with this key already exists"
        }
        if key.contains(" ") {
            return "Key cannot contain spaces"
        }
        return nil
    }

    private var isValid: Bool {
        !key.isEmpty && !isDuplicateKey(key) && !key.contains(" ")
    }
}

#Preview("Environment Variable Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.environmentVariables = [
        EditableEnvironmentVariable(key: "CLAUDE_CODE_MAX_OUTPUT_TOKENS", value: "16384"),
        EditableEnvironmentVariable(key: "API_KEY", value: "sk-1234567890")
    ]

    return EnvironmentVariableEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 500)
}
