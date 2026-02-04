import SwiftUI

// MARK: - EditingTargetPicker

/// Picker for selecting the editing target file.
struct EditingTargetPicker: View {
    @Binding var selection: EditingTarget
    var targets: [EditingTarget] = EditingTarget.projectTargets

    var body: some View {
        Picker("Save to:", selection: $selection) {
            ForEach(targets) { target in
                HStack {
                    Image(systemName: target.source.icon)
                    Text(target.label)
                }
                .tag(target)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 350)
        .help(selection.description)
    }
}

// MARK: - ConflictResolutionSheet

/// Sheet for resolving external file change conflicts.
struct ConflictResolutionSheet: View {
    // MARK: Internal

    let fileName: String
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title)
                Text("External Changes Detected")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("The file \(fileName) was modified externally while you have unsaved changes.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 12) {
                Button {
                    onResolve(.keepLocal)
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Keep My Changes")
                                .fontWeight(.medium)
                            Text("Discard external changes and keep your edits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onResolve(.useExternal)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Use External Version")
                                .fontWeight(.medium)
                            Text("Discard your edits and reload the external changes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - DirtyStateIndicator

/// Indicator shown when there are unsaved changes.
struct DirtyStateIndicator: View {
    let isDirty: Bool

    var body: some View {
        if isDirty {
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
                .help("Unsaved changes")
        }
    }
}

// MARK: - SaveButton

/// Save button that shows state based on dirty flag.
struct SaveButton: View {
    let isDirty: Bool
    let isSaving: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Save", systemImage: "square.and.arrow.down")
            }
        }
        .disabled(!isDirty || isSaving)
        .keyboardShortcut("s", modifiers: .command)
    }
}

// MARK: - EditSettingsButton

/// Button to open the settings editor.
struct EditSettingsButton: View {
    // MARK: Internal

    let projectPath: String

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            Label("Edit Settings", systemImage: "pencil")
        }
        .sheet(isPresented: $showingEditor) {
            ProjectSettingsEditorView(projectPath: projectPath)
        }
    }

    // MARK: Private

    @State private var showingEditor = false
}
