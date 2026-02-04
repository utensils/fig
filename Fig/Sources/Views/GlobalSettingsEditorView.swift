import SwiftUI

// MARK: - GlobalSettingsEditorView

/// Full-featured settings editor for global settings with editing, saving, undo/redo, and conflict handling.
struct GlobalSettingsEditorView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Header with save button and dirty indicator
            editorHeader

            Divider()

            // Tab content
            if viewModel.isLoading {
                ProgressView("Loading settings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    PermissionRuleEditorView(viewModel: viewModel)
                        .tabItem {
                            Label("Permissions", systemImage: "lock.shield")
                        }
                        .tag(EditorTab.permissions)

                    EnvironmentVariableEditorView(viewModel: viewModel)
                        .tabItem {
                            Label("Environment", systemImage: "list.bullet.rectangle")
                        }
                        .tag(EditorTab.environment)

                    AttributionSettingsEditorView(viewModel: viewModel)
                        .tabItem {
                            Label("General", systemImage: "gearshape")
                        }
                        .tag(EditorTab.general)
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .interactiveDismissDisabled(viewModel.isDirty)
        .task {
            await viewModel.loadSettings()
        }
        .onDisappear {
            if viewModel.isDirty {
                Log.general.warning("Global editor closed with unsaved changes")
            }
            onDismiss?()
        }
        .confirmationDialog(
            "Unsaved Changes",
            isPresented: $showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save and Close") {
                Task {
                    do {
                        try await viewModel.save()
                        dismiss()
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Would you like to save them before closing?")
        }
        .sheet(isPresented: $showingConflictSheet) {
            if let url = viewModel.externalChangeURL {
                ConflictResolutionSheet(fileName: url.lastPathComponent) { resolution in
                    Task {
                        await viewModel.resolveConflict(resolution)
                    }
                    showingConflictSheet = false
                }
            }
        }
        .onChange(of: viewModel.hasExternalChanges) { _, hasChanges in
            if hasChanges {
                showingConflictSheet = true
            }
        }
        .onAppear {
            viewModel.undoManager = undoManager
        }
    }

    /// Callback when editor is dismissed (for parent to reload data).
    var onDismiss: (() -> Void)?

    // MARK: Private

    private enum EditorTab: String, CaseIterable, Identifiable {
        case permissions
        case environment
        case general

        var id: String { rawValue }
    }

    @State private var viewModel = SettingsEditorViewModel.forGlobal()
    @State private var selectedTab: EditorTab = .permissions
    @State private var showingCloseConfirmation = false
    @State private var showingConflictSheet = false

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.undoManager)
    private var undoManager

    private var editorHeader: some View {
        HStack {
            // Global settings info
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Global Settings")
                            .font(.title3)
                            .fontWeight(.semibold)

                        DirtyStateIndicator(isDirty: viewModel.isDirty)
                    }

                    Text("~/.claude/settings.json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Undo/Redo buttons
            HStack(spacing: 4) {
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo")

                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Redo")
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // Save button
            SaveButton(
                isDirty: viewModel.isDirty,
                isSaving: viewModel.isSaving
            ) {
                Task {
                    do {
                        try await viewModel.save()
                        NotificationManager.shared.showSuccess("Global Settings Saved")
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Global Settings Editor") {
    GlobalSettingsEditorView()
}
