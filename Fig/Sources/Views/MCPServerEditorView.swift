import SwiftUI

// MARK: - MCPServerEditorView

/// Form view for adding or editing MCP server configurations.
struct MCPServerEditorView: View {
    // MARK: Internal

    enum Field: Hashable {
        case name
        case command
        case url
    }

    @Bindable var viewModel: MCPServerEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.header

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Server identity section
                    self.identitySection

                    // Target location section
                    self.scopeSection

                    // Type-specific configuration
                    if self.viewModel.formData.serverType == .stdio {
                        self.stdioSection
                    } else {
                        self.httpSection
                    }

                    // Import section
                    self.importSection
                }
                .padding()
            }

            Divider()

            // Footer with buttons
            self.footer
        }
        .frame(width: 550, height: 600)
        .onChange(of: self.viewModel.formData.name) { _, _ in self.viewModel.validate() }
        .onChange(of: self.viewModel.formData.command) { _, _ in self.viewModel.validate() }
        .onChange(of: self.viewModel.formData.url) { _, _ in self.viewModel.validate() }
        .onChange(of: self.viewModel.formData.scope) { _, _ in self.viewModel.validate() }
        .onAppear {
            self.viewModel.validate()
            self.focusedField = self.viewModel.isEditing ? .command : .name
        }
    }

    // MARK: Private

    private enum ImportType: String, CaseIterable, Identifiable {
        case json = "JSON"
        case cli = "CLI Command"

        // MARK: Internal

        var id: String {
            rawValue
        }
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var importType: ImportType = .json

    private var header: some View {
        HStack {
            Image(systemName: self.viewModel.formData.serverType.icon)
                .font(.title2)
                .foregroundStyle(self.viewModel.formData.serverType == .http ? .blue : .green)

            Text(self.viewModel.formTitle)
                .font(.headline)

            Spacer()
        }
        .padding()
    }

    private var identitySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Server name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Name")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("my-server", text: self.$viewModel.formData.name)
                        .textFieldStyle(.roundedBorder)
                        .focused(self.$focusedField, equals: .name)
                        .accessibilityLabel("Server name")

                    if let error = viewModel.error(for: "name") {
                        Text(error.message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Server type picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Type")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Type", selection: self.$viewModel.formData.serverType) {
                        ForEach(MCPServerType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Server Identity", systemImage: "tag")
        }
    }

    private var scopeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text("Save Location")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Scope", selection: self.$viewModel.formData.scope) {
                    ForEach(MCPServerScope.allCases) { scope in
                        Label(scope.displayName, systemImage: scope.icon)
                            .tag(scope)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(self.viewModel.projectPath == nil && self.viewModel.formData.scope == .project)
            }
            .padding(.vertical, 4)
        } label: {
            Label("Target Location", systemImage: "folder")
        }
    }

    private var stdioSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Command
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("npx", text: self.$viewModel.formData.command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused(self.$focusedField, equals: .command)
                        .accessibilityLabel("Command")

                    if let error = viewModel.error(for: "command") {
                        Text(error.message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Arguments
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Arguments")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }

                    TagInputView(
                        tags: self.$viewModel.formData.args,
                        placeholder: "Add argument..."
                    )
                }

                // Environment variables
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Environment Variables")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button {
                            self.viewModel.formData.addEnvVar()
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add environment variable")
                    }

                    if self.viewModel.formData.envVars.isEmpty {
                        Text("No environment variables")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(self.viewModel.formData.envVars.enumerated()), id: \.element.id) { index, _ in
                            KeyValueRow(
                                key: self.$viewModel.formData.envVars[index].key,
                                value: self.$viewModel.formData.envVars[index].value,
                                keyPlaceholder: "KEY",
                                valuePlaceholder: "value",
                                onDelete: {
                                    self.viewModel.formData.removeEnvVar(at: index)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Stdio Configuration", systemImage: "terminal")
        }
    }

    private var httpSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // URL
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("https://mcp.example.com/api", text: self.$viewModel.formData.url)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused(self.$focusedField, equals: .url)
                        .accessibilityLabel("Server URL")

                    if let error = viewModel.error(for: "url") {
                        Text(error.message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Headers
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Headers")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button {
                            self.viewModel.formData.addHeader()
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add header")
                    }

                    if self.viewModel.formData.headers.isEmpty {
                        Text("No headers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(self.viewModel.formData.headers.enumerated()), id: \.element.id) { index, _ in
                            KeyValueRow(
                                key: self.$viewModel.formData.headers[index].key,
                                value: self.$viewModel.formData.headers[index].value,
                                keyPlaceholder: "Header-Name",
                                valuePlaceholder: "value",
                                onDelete: {
                                    self.viewModel.formData.removeHeader(at: index)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("HTTP Configuration", systemImage: "globe")
        }
    }

    private var importSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Import Type", selection: self.$importType) {
                    ForEach(ImportType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: self.$importText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Button("Import") {
                        let success = if self.importType == .json {
                            self.viewModel.importFromJSON(self.importText)
                        } else {
                            self.viewModel.importFromCLICommand(self.importText)
                        }
                        if success {
                            self.importText = ""
                        }
                    }
                    .disabled(self.importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Import from JSON / CLI", systemImage: "square.and.arrow.down")
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                self.dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(self.viewModel.isEditing ? "Save" : "Add Server") {
                Task {
                    if await self.viewModel.save() {
                        self.dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!self.viewModel.canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

// MARK: - TagInputView

/// A view for entering tags/arguments with add/remove functionality.
struct TagInputView: View {
    // MARK: Internal

    @Binding var tags: [String]

    var placeholder: String = "Add tag..."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tag display
            FlowLayout(spacing: 4) {
                ForEach(Array(self.tags.enumerated()), id: \.offset) { index, tag in
                    TagChip(text: tag) {
                        self.tags.remove(at: index)
                    }
                }
            }

            // Input field
            HStack {
                TextField(self.placeholder, text: self.$newTagText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        self.addTag()
                    }

                Button {
                    self.addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(self.newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: Private

    @State private var newTagText = ""

    private func addTag() {
        let trimmed = self.newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return
        }
        self.tags.append(trimmed)
        self.newTagText = ""
    }
}

// MARK: - TagChip

/// A removable tag chip.
struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(self.text)
                .font(.system(.caption, design: .monospaced))

            Button {
                self.onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(self.text)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - KeyValueRow

/// A row for entering key-value pairs with delete button.
struct KeyValueRow: View {
    @Binding var key: String
    @Binding var value: String

    var keyPlaceholder: String = "Key"
    var valuePlaceholder: String = "Value"
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(self.keyPlaceholder, text: self.$key)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 150)

            Text("=")
                .foregroundStyle(.secondary)

            TextField(self.valuePlaceholder, text: self.$value)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))

            Button {
                self.onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove entry")
        }
    }
}

#Preview("Add Server") {
    MCPServerEditorView(
        viewModel: MCPServerEditorViewModel.forAdding(
            projectPath: URL(fileURLWithPath: "/tmp/test-project")
        )
    )
}

#Preview("Edit Server") {
    MCPServerEditorView(
        viewModel: MCPServerEditorViewModel.forEditing(
            name: "github",
            server: .stdio(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_TOKEN": "ghp_xxx"]
            ),
            scope: .project,
            projectPath: URL(fileURLWithPath: "/tmp/test-project")
        )
    )
}
