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
                if !viewModel.isGlobalMode {
                    HStack {
                        EditingTargetPicker(selection: $viewModel.editingTarget)
                        Spacer()
                    }
                }

                // Attribution settings
                GroupBox("Attribution") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: commitBinding) {
                            VStack(alignment: .leading) {
                                Text("Commit Attribution")
                                    .font(.body)
                                Text("Include Claude Code attribution in commit messages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: pullRequestBinding) {
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
                            ForEach(viewModel.disallowedTools, id: \.self) { tool in
                                DisallowedToolTag(tool: tool) {
                                    viewModel.removeDisallowedTool(tool)
                                }
                            }

                            // Add new tag
                            if isAddingTool {
                                AddToolInput(
                                    toolName: $newToolName,
                                    onAdd: addNewTool,
                                    onCancel: {
                                        isAddingTool = false
                                        newToolName = ""
                                    }
                                )
                            } else {
                                AddToolButton {
                                    isAddingTool = true
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if viewModel.disallowedTools.isEmpty, !isAddingTool {
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
            get: { viewModel.attribution?.commits ?? false },
            set: { newValue in
                viewModel.updateAttribution(
                    commits: newValue,
                    pullRequests: viewModel.attribution?.pullRequests
                )
            }
        )
    }

    private var pullRequestBinding: Binding<Bool> {
        Binding(
            get: { viewModel.attribution?.pullRequests ?? false },
            set: { newValue in
                viewModel.updateAttribution(
                    commits: viewModel.attribution?.commits,
                    pullRequests: newValue
                )
            }
        )
    }

    private func addNewTool() {
        guard !newToolName.isEmpty else { return }
        viewModel.addDisallowedTool(newToolName)
        newToolName = ""
        isAddingTool = false
    }
}

// MARK: - DisallowedToolTag

/// A tag displaying a disallowed tool with remove button.
struct DisallowedToolTag: View {
    let tool: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tool)
                .font(.system(.caption, design: .monospaced))
            Button(action: onRemove) {
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
            TextField("Tool name", text: $toolName)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 80, maxWidth: 120)
                .onSubmit {
                    onAdd()
                }

            Button(action: onAdd) {
                Image(systemName: "checkmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .disabled(toolName.isEmpty)

            Button(action: onCancel) {
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
        Button(action: action) {
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
