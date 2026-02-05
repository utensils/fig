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
            self.editorHeader

            Divider()

            // Tab content
            if self.viewModel.isLoading {
                ProgressView("Loading configuration...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: self.$selectedTab) {
                    PermissionRuleEditorView(
                        viewModel: self.viewModel,
                        onPromoteToGlobal: { rule, type in
                            self.ruleToPromote = RulePromotionInfo(rule: rule, type: type)
                            self.showPromoteConfirmation = true
                        }
                    )
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
        .navigationTitle(self.windowTitle)
        .task {
            await self.viewModel.loadSettings()
        }
        .onDisappear {
            if self.viewModel.isDirty {
                // The confirmation dialog should have been shown before navigation
                Log.general.warning("Editor closed with unsaved changes")
            }
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
                        self.closeAction?()
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                self.closeAction?()
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
        .promoteToGlobalAlert(
            isPresented: self.$showPromoteConfirmation,
            ruleToPromote: self.$ruleToPromote,
            projectURL: self.viewModel.projectURL
        )
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

    @State private var viewModel: SettingsEditorViewModel
    @State private var selectedTab: EditorTab = .permissions
    @State private var showingCloseConfirmation = false
    @State private var showingConflictSheet = false
    @State private var closeAction: (() -> Void)?
    @State private var showPromoteConfirmation = false
    @State private var ruleToPromote: RulePromotionInfo?

    @Environment(\.undoManager)
    private var undoManager

    private var windowTitle: String {
        var title = self.viewModel.displayName
        if self.viewModel.isDirty {
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
                        Text(self.viewModel.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        DirtyStateIndicator(isDirty: self.viewModel.isDirty)
                    }

                    Text(self.abbreviatePath(self.viewModel.projectPath ?? ""))
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
