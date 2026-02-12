import SwiftUI

// MARK: - HookEditorView

/// Editor view for managing hook configurations across lifecycle events.
struct HookEditorView: View {
    // MARK: Internal

    @Bindable var viewModel: SettingsEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Target selector and templates
                HStack {
                    if !viewModel.isGlobalMode {
                        EditingTargetPicker(selection: $viewModel.editingTarget)
                    }

                    Spacer()

                    Menu {
                        ForEach(HookTemplate.allTemplates) { template in
                            Button {
                                viewModel.applyHookTemplate(template)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } label: {
                        Label("Templates", systemImage: "bolt.fill")
                    }
                }

                // One section per lifecycle event
                ForEach(HookEvent.allCases) { event in
                    EditableHookEventSection(
                        event: event,
                        groups: viewModel.hookGroups[event.rawValue] ?? [],
                        viewModel: viewModel,
                        onAddGroup: {
                            addingForEvent = event
                            showingAddHookGroup = true
                        }
                    )
                }

                // Show unrecognized hook events that exist in settings
                // but aren't in the HookEvent enum (e.g., future event types)
                let unrecognizedEvents = viewModel.hookGroups.keys
                    .filter { key in !HookEvent.allCases.contains(where: { $0.rawValue == key }) }
                    .sorted()

                if !unrecognizedEvents.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Other Events", systemImage: "questionmark.circle")
                                .font(.headline)

                            Text(
                                "These hook events are not recognized by this editor but will be preserved when saving."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            ForEach(unrecognizedEvents, id: \.self) { eventKey in
                                let groupCount = viewModel.hookGroups[eventKey]?.count ?? 0
                                HStack {
                                    Text(eventKey)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text(
                                        "\(groupCount) group\(groupCount == 1 ? "" : "s")"
                                    )
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Help reference
                HookVariablesReference()

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingAddHookGroup) {
            AddHookGroupSheet(event: addingForEvent) { matcher, commands in
                viewModel.addHookGroup(
                    event: addingForEvent.rawValue,
                    matcher: matcher,
                    commands: commands
                )
            }
        }
    }

    // MARK: Private

    @State private var showingAddHookGroup = false
    @State private var addingForEvent: HookEvent = .preToolUse
}

// MARK: - EditableHookEventSection

/// A section displaying hook groups for a specific lifecycle event.
struct EditableHookEventSection: View {
    // MARK: Internal

    let event: HookEvent
    let groups: [EditableHookGroup]
    @Bindable var viewModel: SettingsEditorViewModel
    let onAddGroup: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(event.displayName, systemImage: event.icon)
                        .font(.headline)

                    Spacer()

                    Button {
                        onAddGroup()
                    } label: {
                        Label("Add Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                Text(event.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if groups.isEmpty {
                    Text("No hooks configured.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        EditableHookGroupRow(
                            event: event,
                            group: group,
                            groupIndex: index,
                            groupCount: groups.count,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - EditableHookGroupRow

/// A row displaying a hook group with its matcher and command list.
struct EditableHookGroupRow: View {
    // MARK: Internal

    let event: HookEvent
    let group: EditableHookGroup
    let groupIndex: Int
    let groupCount: Int
    @Bindable var viewModel: SettingsEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Matcher row
            HStack {
                if event.supportsMatcher {
                    if isEditingMatcher {
                        TextField("Matcher pattern", text: $editedMatcher)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                saveMatcher()
                            }

                        Button("Save") {
                            saveMatcher()
                        }

                        Button("Cancel") {
                            isEditingMatcher = false
                            editedMatcher = group.matcher
                        }
                    } else {
                        Label(
                            group.matcher.isEmpty ? "All tools" : group.matcher,
                            systemImage: "target"
                        )
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(group.matcher.isEmpty ? .secondary : .primary)

                        Button {
                            startEditingMatcher()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Label("All events", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Reorder buttons
                if groupCount > 1 {
                    Button {
                        viewModel.moveHookGroup(
                            event: event.rawValue,
                            from: groupIndex,
                            direction: -1
                        )
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupIndex == 0)
                    .help("Move up")

                    Button {
                        viewModel.moveHookGroup(
                            event: event.rawValue,
                            from: groupIndex,
                            direction: 1
                        )
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(groupIndex == groupCount - 1)
                    .help("Move down")
                }

                // Add command button
                Button {
                    showingAddCommand = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Add command")

                // Delete group button
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            // Hook definitions (commands)
            ForEach(Array(group.hooks.enumerated()), id: \.element.id) { hookIndex, hook in
                HookDefinitionRow(
                    hook: hook,
                    hookIndex: hookIndex,
                    hookCount: group.hooks.count,
                    onUpdate: { newCommand in
                        viewModel.updateHookDefinition(
                            event: event.rawValue,
                            groupID: group.id,
                            hook: hook,
                            newCommand: newCommand
                        )
                    },
                    onDelete: {
                        viewModel.removeHookDefinition(
                            event: event.rawValue,
                            groupID: group.id,
                            hook: hook
                        )
                    },
                    onMove: { direction in
                        viewModel.moveHookDefinition(
                            event: event.rawValue,
                            groupID: group.id,
                            from: hookIndex,
                            direction: direction
                        )
                    }
                )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
        .confirmationDialog(
            "Delete Hook Group",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.removeHookGroup(event: event.rawValue, group: group)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this hook group?")
        }
        .sheet(isPresented: $showingAddCommand) {
            AddHookCommandSheet { command in
                viewModel.addHookDefinition(
                    event: event.rawValue,
                    groupID: group.id,
                    command: command
                )
            }
        }
    }

    // MARK: Private

    @State private var isEditingMatcher = false
    @State private var editedMatcher = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingAddCommand = false

    private func startEditingMatcher() {
        editedMatcher = group.matcher
        isEditingMatcher = true
    }

    private func saveMatcher() {
        viewModel.updateHookGroupMatcher(
            event: event.rawValue,
            group: group,
            newMatcher: editedMatcher
        )
        isEditingMatcher = false
    }
}

// MARK: - HookDefinitionRow

/// A row displaying a single hook command with inline editing.
struct HookDefinitionRow: View {
    // MARK: Internal

    let hook: EditableHookDefinition
    let hookIndex: Int
    let hookCount: Int
    let onUpdate: (String) -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundStyle(.blue)
                .frame(width: 20)

            if isEditing {
                TextField("Command", text: $editedCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        saveEdit()
                    }

                Button("Save") {
                    saveEdit()
                }
                .disabled(editedCommand.isEmpty)

                Button("Cancel") {
                    isEditing = false
                    editedCommand = hook.command
                }
            } else {
                Text(hook.command)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Reorder buttons
                if hookCount > 1 {
                    Button {
                        onMove(-1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(hookIndex == 0)

                    Button {
                        onMove(1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(hookIndex == hookCount - 1)
                }

                Button {
                    isEditing = true
                    editedCommand = hook.command
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
        .padding(.vertical, 2)
        .padding(.leading, 20)
        .confirmationDialog(
            "Delete Command",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this command?\n\(hook.command)")
        }
    }

    // MARK: Private

    @State private var isEditing = false
    @State private var editedCommand = ""
    @State private var showingDeleteConfirmation = false

    private func saveEdit() {
        guard !editedCommand.isEmpty else { return }
        onUpdate(editedCommand)
        isEditing = false
    }
}

// MARK: - AddHookGroupSheet

/// Sheet for adding a new hook group with matcher and command.
struct AddHookGroupSheet: View {
    // MARK: Internal

    let event: HookEvent
    let onAdd: (String, [String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: event.icon)
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Add Hook Group \u{2014} \(event.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Matcher input (if supported)
            if event.supportsMatcher {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matcher Pattern")
                        .font(.headline)
                    TextField(event.matcherPlaceholder, text: $matcher)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("Use tool name with optional glob pattern. Leave empty to match all.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Command input
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.headline)
                TextField("e.g., npm run lint, black $CLAUDE_FILE_PATH", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Shell command to run. You can add more commands after creation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("When")
                        .foregroundStyle(.secondary)
                    Text(event.displayName)
                        .fontWeight(.medium)
                    if event.supportsMatcher, !matcher.isEmpty {
                        Text("matches")
                            .foregroundStyle(.secondary)
                        Text(matcher)
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("\u{2192}")
                        .foregroundStyle(.secondary)
                    Text("Run")
                        .foregroundStyle(.secondary)
                    Text(command.isEmpty ? "..." : command)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Hook Group") {
                    onAdd(matcher, [command])
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 420)
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss

    @State private var matcher = ""
    @State private var command = ""
}

// MARK: - AddHookCommandSheet

/// Sheet for adding a command to an existing hook group.
struct AddHookCommandSheet: View {
    // MARK: Internal

    let onAdd: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Add Command")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.headline)
                TextField("Shell command to execute", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Command") {
                    onAdd(command)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss

    @State private var command = ""
}

// MARK: - HookVariablesReference

/// Reference section for available hook variables.
struct HookVariablesReference: View {
    var isCollapsible = true

    var body: some View {
        if isCollapsible {
            DisclosureGroup("Available Hook Variables") {
                variablesList
            }
            .padding()
            .background(
                .quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 8)
            )
        } else {
            GroupBox("Available Hook Variables") {
                variablesList
            }
        }
    }

    private var variablesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(HookVariable.all) { variable in
                HookVariableRow(variable: variable)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - HookVariableRow

/// A row displaying a hook variable with click-to-copy and event scope.
struct HookVariableRow: View {
    let variable: HookVariable

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(variable.name, forType: .string)
                NotificationManager.shared.showSuccess(
                    "Copied",
                    message: variable.name
                )
            } label: {
                HStack(spacing: 4) {
                    Text(variable.name)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .help("Click to copy")

            Text(variable.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(variable.events) { event in
                    HookEventBadge(event: event)
                }
            }
        }
    }
}

// MARK: - HookEventBadge

/// A small colored badge indicating a hook event scope.
struct HookEventBadge: View {
    let event: HookEvent

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: event.icon)
                .font(.system(size: 8))
            Text(event.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            event.color.opacity(0.2),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .foregroundStyle(event.color)
    }
}

// MARK: - Preview

#Preview("Hook Editor") {
    let viewModel = SettingsEditorViewModel(projectPath: "/Users/test/project")
    viewModel.hookGroups = [
        "PostToolUse": [
            EditableHookGroup(
                matcher: "Write(*.py)",
                hooks: [
                    EditableHookDefinition(type: "command", command: "black $CLAUDE_FILE_PATH"),
                ]
            ),
        ],
    ]

    return HookEditorView(viewModel: viewModel)
        .padding()
        .frame(width: 600, height: 600)
}
