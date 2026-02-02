import SwiftUI

// MARK: - ProjectSettingsEditorView

/// Full-featured settings editor view for a project with editing, saving, undo/redo, and conflict handling.
struct ProjectSettingsEditorView: View {
    // MARK: Lifecycle

    init(projectPath: String) {
        _viewModel = State(initialValue: SettingsEditorViewModel(projectPath: projectPath))
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Header with save button and dirty indicator
            editorHeader

            Divider()

            // Tab content
            if viewModel.isLoading {
                ProgressView("Loading configuration...")
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
        .navigationTitle(windowTitle)
        .task {
            await viewModel.loadSettings()
        }
        .onDisappear {
            if viewModel.isDirty {
                // The confirmation dialog should have been shown before navigation
                Log.general.warning("Editor closed with unsaved changes")
            }
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
                        closeAction?()
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                closeAction?()
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

    // MARK: Private

    private enum EditorTab: String, CaseIterable, Identifiable {
        case permissions
        case environment
        case general

        var id: String { rawValue }
    }

    @State private var viewModel: SettingsEditorViewModel
    @State private var selectedTab: EditorTab = .permissions
    @State private var showingCloseConfirmation = false
    @State private var showingConflictSheet = false
    @State private var closeAction: (() -> Void)?

    @Environment(\.undoManager) private var undoManager

    private var windowTitle: String {
        var title = viewModel.projectName
        if viewModel.isDirty {
            title += " \u{2022}" // bullet point
        }
        return title
    }

    private var editorHeader: some View {
        HStack {
            // Project info
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(viewModel.projectName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        DirtyStateIndicator(isDirty: viewModel.isDirty)
                    }

                    Text(abbreviatePath(viewModel.projectPath))
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
                        NotificationManager.shared.showSuccess("Settings Saved")
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
        }
        .padding()
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Preview

#Preview("Settings Editor") {
    ProjectSettingsEditorView(projectPath: "/Users/test/project")
}
