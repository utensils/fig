import SwiftUI

// MARK: - AttributionSettingsEditorView

/// Editor view for attribution and general settings.
struct AttributionSettingsEditorView: View {
    // MARK: Internal

    @Bindable var viewModel: SettingsEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Target selector
                if !self.viewModel.isGlobalMode {
                    HStack {
                        EditingTargetPicker(selection: self.$viewModel.editingTarget)
                        Spacer()
                    }
                }

                // Attribution settings
                GroupBox("Attribution") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: self.commitBinding) {
                            VStack(alignment: .leading) {
                                Text("Commit Attribution")
                                    .font(.body)
                                Text("Include Claude Code attribution in commit messages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: self.pullRequestBinding) {
                            VStack(alignment: .leading) {
                                Text("Pull Request Attribution")
                                    .font(.body)
                                Text("Include Claude Code attribution in PR descriptions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Disallowed tools
                GroupBox("Disallowed Tools") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tools that Claude Code is not allowed to use")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Tag input area
                        FlowLayout(spacing: 8) {
                            ForEach(self.viewModel.disallowedTools, id: \.self) { tool in
                                DisallowedToolTag(tool: tool) {
                                    self.viewModel.removeDisallowedTool(tool)
                                }
                            }

                            // Add new tag
                            if self.isAddingTool {
                                AddToolInput(
                                    toolName: self.$newToolName,
                                    onAdd: self.addNewTool,
                                    onCancel: {
                                        self.isAddingTool = false
                                        self.newToolName = ""
                                    }
                                )
                            } else {
                                AddToolButton {
                                    self.isAddingTool = true
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if self.viewModel.disallowedTools.isEmpty, !self.isAddingTool {
                            Text("No tools are disallowed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    @State private var isAddingTool = false
    @State private var newToolName = ""

    private var commitBinding: Binding<Bool> {
        Binding(
            get: { self.viewModel.attribution?.commits ?? false },
            set: { newValue in
                self.viewModel.updateAttribution(
                    commits: newValue,
                    pullRequests: self.viewModel.attribution?.pullRequests
                )
            }
        )
    }

    private var pullRequestBinding: Binding<Bool> {
        Binding(
            get: { self.viewModel.attribution?.pullRequests ?? false },
            set: { newValue in
                self.viewModel.updateAttribution(
                    commits: self.viewModel.attribution?.commits,
                    pullRequests: newValue
                )
            }
        )
    }

    private func addNewTool() {
        guard !self.newToolName.isEmpty else {
            return
        }
        self.viewModel.addDisallowedTool(self.newToolName)
        self.newToolName = ""
        self.isAddingTool = false
    }
}

// MARK: - DisallowedToolTag

/// A tag displaying a disallowed tool with remove button.
struct DisallowedToolTag: View {
    let tool: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(self.tool)
                .font(.system(.caption, design: .monospaced))
            Button(action: self.onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.red.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - AddToolInput

/// Input field for adding a new disallowed tool.
struct AddToolInput: View {
    @Binding var toolName: String

    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Tool name", text: self.$toolName)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 80, maxWidth: 120)
                .onSubmit {
                    self.onAdd()
                }

            Button(action: self.onAdd) {
                Image(systemName: "checkmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .disabled(self.toolName.isEmpty)

            Button(action: self.onCancel) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - AddToolButton

/// Button to start adding a new disallowed tool.
struct AddToolButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text("Add Tool")
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("Attribution Settings Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.attribution = Attribution(commits: true, pullRequests: false)
    viewModel.disallowedTools = ["Bash", "WebFetch"]

    return AttributionSettingsEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 500)
}
