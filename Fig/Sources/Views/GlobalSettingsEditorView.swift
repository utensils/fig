import SwiftUI

// MARK: - GlobalSettingsEditorView

/// Full-featured settings editor for global settings with editing, saving, undo/redo, and conflict handling.
struct GlobalSettingsEditorView: View {
    // MARK: Internal

    /// Callback when editor is dismissed (for parent to reload data).
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with save button and dirty indicator
            self.editorHeader

            Divider()

            // Tab content
            if self.viewModel.isLoading {
                ProgressView("Loading settings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: self.$selectedTab) {
                    PermissionRuleEditorView(viewModel: self.viewModel)
                        .tabItem {
                            Label("Permissions", systemImage: "lock.shield")
                        }
                        .tag(EditorTab.permissions)

                    EnvironmentVariableEditorView(viewModel: self.viewModel)
                        .tabItem {
                            Label("Environment", systemImage: "list.bullet.rectangle")
                        }
                        .tag(EditorTab.environment)

                    HookEditorView(viewModel: self.viewModel)
                        .tabItem {
                            Label("Hooks", systemImage: "bolt.horizontal")
                        }
                        .tag(EditorTab.hooks)

                    AttributionSettingsEditorView(viewModel: self.viewModel)
                        .tabItem {
                            Label("General", systemImage: "gearshape")
                        }
                        .tag(EditorTab.general)
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .interactiveDismissDisabled(self.viewModel.isDirty)
        .task {
            await self.viewModel.loadSettings()
        }
        .onDisappear {
            if self.viewModel.isDirty {
                Log.general.warning("Global editor closed with unsaved changes")
            }
            self.onDismiss?()
        }
        .confirmationDialog(
            "Unsaved Changes",
            isPresented: self.$showingCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save and Close") {
                Task {
                    do {
                        try await self.viewModel.save()
                        self.dismiss()
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                self.dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Would you like to save them before closing?")
        }
        .sheet(isPresented: self.$showingConflictSheet) {
            if let url = viewModel.externalChangeURL {
                ConflictResolutionSheet(fileName: url.lastPathComponent) { resolution in
                    Task {
                        await self.viewModel.resolveConflict(resolution)
                    }
                    self.showingConflictSheet = false
                }
            }
        }
        .onChange(of: self.viewModel.hasExternalChanges) { _, hasChanges in
            if hasChanges {
                self.showingConflictSheet = true
            }
        }
        .onAppear {
            self.viewModel.undoManager = self.undoManager
        }
    }

    // MARK: Private

    private enum EditorTab: String, CaseIterable, Identifiable {
        case permissions
        case environment
        case hooks
        case general

        // MARK: Internal

        var id: String {
            rawValue
        }
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

                        DirtyStateIndicator(isDirty: self.viewModel.isDirty)
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
                    self.undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!self.viewModel.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo")

                Button {
                    self.undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!self.viewModel.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Redo")
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // Save button
            SaveButton(
                isDirty: self.viewModel.isDirty,
                isSaving: self.viewModel.isSaving
            ) {
                Task {
                    do {
                        try await self.viewModel.save()
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
