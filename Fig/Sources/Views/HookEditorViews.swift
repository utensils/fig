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
                    if !self.viewModel.isGlobalMode {
                        EditingTargetPicker(selection: self.$viewModel.editingTarget)
                    }

                    Spacer()

                    Menu {
                        ForEach(HookTemplate.allTemplates) { template in
                            Button {
                                self.viewModel.applyHookTemplate(template)
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
                        groups: self.viewModel.hookGroups[event.rawValue] ?? [],
                        viewModel: self.viewModel,
                        onAddGroup: {
                            self.addingForEvent = event
                            self.showingAddHookGroup = true
                        }
                    )
                }

                // Show unrecognized hook events that exist in settings
                // but aren't in the HookEvent enum (e.g., future event types)
                let unrecognizedEvents = self.viewModel.hookGroups.keys
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
                                let groupCount = self.viewModel.hookGroups[eventKey]?.count ?? 0
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
        .sheet(isPresented: self.$showingAddHookGroup) {
            AddHookGroupSheet(event: self.addingForEvent) { matcher, commands in
                self.viewModel.addHookGroup(
                    event: self.addingForEvent.rawValue,
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
    let event: HookEvent
    let groups: [EditableHookGroup]
    @Bindable var viewModel: SettingsEditorViewModel

    let onAddGroup: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(self.event.displayName, systemImage: self.event.icon)
                        .font(.headline)

                    Spacer()

                    Button {
                        self.onAddGroup()
                    } label: {
                        Label("Add Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                Text(self.event.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if self.groups.isEmpty {
                    Text("No hooks configured.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(self.groups.enumerated()), id: \.element.id) { index, group in
                        EditableHookGroupRow(
                            event: self.event,
                            group: group,
                            groupIndex: index,
                            groupCount: self.groups.count,
                            viewModel: self.viewModel
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
                if self.event.supportsMatcher {
                    if self.isEditingMatcher {
                        TextField("Matcher pattern", text: self.$editedMatcher)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                self.saveMatcher()
                            }

                        Button("Save") {
                            self.saveMatcher()
                        }

                        Button("Cancel") {
                            self.isEditingMatcher = false
                            self.editedMatcher = self.group.matcher
                        }
                    } else {
                        Label(
                            self.group.matcher.isEmpty ? "All tools" : self.group.matcher,
                            systemImage: "target"
                        )
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(self.group.matcher.isEmpty ? .secondary : .primary)

                        Button {
                            self.startEditingMatcher()
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
                if self.groupCount > 1 {
                    Button {
                        self.viewModel.moveHookGroup(
                            event: self.event.rawValue,
                            from: self.groupIndex,
                            direction: -1
                        )
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.groupIndex == 0)
                    .help("Move up")

                    Button {
                        self.viewModel.moveHookGroup(
                            event: self.event.rawValue,
                            from: self.groupIndex,
                            direction: 1
                        )
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.groupIndex == self.groupCount - 1)
                    .help("Move down")
                }

                // Add command button
                Button {
                    self.showingAddCommand = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Add command")

                // Delete group button
                Button {
                    self.showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            // Hook definitions (commands)
            ForEach(Array(self.group.hooks.enumerated()), id: \.element.id) { hookIndex, hook in
                HookDefinitionRow(
                    hook: hook,
                    hookIndex: hookIndex,
                    hookCount: self.group.hooks.count,
                    onUpdate: { newCommand in
                        self.viewModel.updateHookDefinition(
                            event: self.event.rawValue,
                            groupID: self.group.id,
                            hook: hook,
                            newCommand: newCommand
                        )
                    },
                    onDelete: {
                        self.viewModel.removeHookDefinition(
                            event: self.event.rawValue,
                            groupID: self.group.id,
                            hook: hook
                        )
                    },
                    onMove: { direction in
                        self.viewModel.moveHookDefinition(
                            event: self.event.rawValue,
                            groupID: self.group.id,
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
            isPresented: self.$showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                self.viewModel.removeHookGroup(event: self.event.rawValue, group: self.group)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this hook group?")
        }
        .sheet(isPresented: self.$showingAddCommand) {
            AddHookCommandSheet { command in
                self.viewModel.addHookDefinition(
                    event: self.event.rawValue,
                    groupID: self.group.id,
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
        self.editedMatcher = self.group.matcher
        self.isEditingMatcher = true
    }

    private func saveMatcher() {
        self.viewModel.updateHookGroupMatcher(
            event: self.event.rawValue,
            group: self.group,
            newMatcher: self.editedMatcher
        )
        self.isEditingMatcher = false
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

            if self.isEditing {
                TextField("Command", text: self.$editedCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        self.saveEdit()
                    }

                Button("Save") {
                    self.saveEdit()
                }
                .disabled(self.editedCommand.isEmpty)

                Button("Cancel") {
                    self.isEditing = false
                    self.editedCommand = self.hook.command
                }
            } else {
                Text(self.hook.command)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Reorder buttons
                if self.hookCount > 1 {
                    Button {
                        self.onMove(-1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.hookIndex == 0)

                    Button {
                        self.onMove(1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.hookIndex == self.hookCount - 1)
                }

                Button {
                    self.isEditing = true
                    self.editedCommand = self.hook.command
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
        .padding(.vertical, 2)
        .padding(.leading, 20)
        .confirmationDialog(
            "Delete Command",
            isPresented: self.$showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                self.onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this command?\n\(self.hook.command)")
        }
    }

    // MARK: Private

    @State private var isEditing = false
    @State private var editedCommand = ""
    @State private var showingDeleteConfirmation = false

    private func saveEdit() {
        guard !self.editedCommand.isEmpty else {
            return
        }
        self.onUpdate(self.editedCommand)
        self.isEditing = false
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
                Image(systemName: self.event.icon)
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Add Hook Group \u{2014} \(self.event.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            // Matcher input (if supported)
            if self.event.supportsMatcher {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matcher Pattern")
                        .font(.headline)
                    TextField(self.event.matcherPlaceholder, text: self.$matcher)
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
                TextField("e.g., npm run lint, black $CLAUDE_FILE_PATH", text: self.$command)
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
                    Text(self.event.displayName)
                        .fontWeight(.medium)
                    if self.event.supportsMatcher, !self.matcher.isEmpty {
                        Text("matches")
                            .foregroundStyle(.secondary)
                        Text(self.matcher)
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("\u{2192}")
                        .foregroundStyle(.secondary)
                    Text("Run")
                        .foregroundStyle(.secondary)
                    Text(self.command.isEmpty ? "..." : self.command)
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
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Hook Group") {
                    self.onAdd(self.matcher, [self.command])
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(self.command.isEmpty)
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
                TextField("Shell command to execute", text: self.$command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Command") {
                    self.onAdd(self.command)
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(self.command.isEmpty)
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

/// Collapsible reference section for available hook variables.
struct HookVariablesReference: View {
    var body: some View {
        DisclosureGroup("Available Hook Variables") {
            VStack(alignment: .leading, spacing: 8) {
                HookVariableRow(
                    name: "$CLAUDE_TOOL_NAME",
                    description: "Name of the tool being used"
                )
                HookVariableRow(
                    name: "$CLAUDE_TOOL_INPUT",
                    description: "JSON input to the tool"
                )
                HookVariableRow(
                    name: "$CLAUDE_FILE_PATH",
                    description: "File path affected (if applicable)"
                )
                HookVariableRow(
                    name: "$CLAUDE_TOOL_OUTPUT",
                    description: "Output from the tool (PostToolUse only)"
                )
                HookVariableRow(
                    name: "$CLAUDE_NOTIFICATION",
                    description: "Notification message (Notification only)"
                )
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - HookVariableRow

/// A row displaying a hook variable name and description.
struct HookVariableRow: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.name)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
            Text(self.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
