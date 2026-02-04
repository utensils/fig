import SwiftUI

// MARK: - ProjectDetailView

/// Detail view for a selected project showing tabbed configuration.
struct ProjectDetailView: View {
    // MARK: Lifecycle

    init(projectPath: String) {
        _viewModel = State(initialValue: ProjectDetailViewModel(projectPath: projectPath))
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ProjectHeaderView(
                viewModel: viewModel,
                onExport: {
                    exportViewModel = ConfigExportViewModel(
                        projectPath: viewModel.projectURL,
                        projectName: viewModel.projectName
                    )
                    showExportSheet = true
                },
                onImport: {
                    importViewModel = ConfigImportViewModel(
                        projectPath: viewModel.projectURL,
                        projectName: viewModel.projectName
                    )
                    showImportSheet = true
                }
            )

            Divider()

            // Tab content
            if viewModel.isLoading {
                ProgressView("Loading configuration...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.projectExists {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text("The project directory no longer exists at:\n\(viewModel.projectPath)")
                )
            } else {
                TabView(selection: $viewModel.selectedTab) {
                    ForEach(ProjectDetailTab.allCases) { tab in
                        tabContent(for: tab)
                            .tabItem {
                                Label(tab.title, systemImage: tab.icon)
                            }
                            .tag(tab)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500)
        .task {
            await viewModel.loadConfiguration()
        }
        .sheet(isPresented: $showMCPServerEditor, onDismiss: {
            Task {
                await viewModel.loadConfiguration()
            }
        }) {
            if let editorViewModel = mcpEditorViewModel {
                MCPServerEditorView(viewModel: editorViewModel)
            }
        }
        .alert(
            "Delete Server",
            isPresented: $showDeleteConfirmation,
            presenting: serverToDelete
        ) { server in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteMCPServer(name: server.name, source: server.source)
                }
            }
        } message: { server in
            Text("Are you sure you want to delete '\(server.name)'? This action cannot be undone.")
        }
        .sheet(isPresented: $showCopySheet, onDismiss: {
            Task {
                await viewModel.loadConfiguration()
            }
        }) {
            if let copyVM = copyViewModel {
                MCPCopySheet(viewModel: copyVM)
                    .task {
                        // Load projects for destination picker
                        let config = try? await ConfigFileManager.shared.readGlobalConfig()
                        let projects = config?.allProjects ?? []
                        copyVM.loadDestinations(projects: projects)
                    }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportVM = exportViewModel {
                ConfigExportView(viewModel: exportVM)
            }
        }
        .sheet(isPresented: $showImportSheet, onDismiss: {
            Task {
                await viewModel.loadConfiguration()
            }
        }) {
            if let importVM = importViewModel {
                ConfigImportView(viewModel: importVM)
            }
        }
        .promoteToGlobalAlert(
            isPresented: $showPromoteConfirmation,
            ruleToPromote: $ruleToPromote,
            projectURL: viewModel.projectURL,
            onComplete: { await viewModel.loadConfiguration() }
        )
    }

    // MARK: Private

    @State private var viewModel: ProjectDetailViewModel
    @State private var showMCPServerEditor = false
    @State private var mcpEditorViewModel: MCPServerEditorViewModel?
    @State private var showDeleteConfirmation = false
    @State private var serverToDelete: (name: String, source: ConfigSource)?
    @State private var showCopySheet = false
    @State private var copyViewModel: MCPCopyViewModel?
    @State private var showExportSheet = false
    @State private var exportViewModel: ConfigExportViewModel?
    @State private var showImportSheet = false
    @State private var importViewModel: ConfigImportViewModel?
    @State private var showPromoteConfirmation = false
    @State private var ruleToPromote: RulePromotionInfo?

    private var permissionsTabContent: some View {
        PermissionsTabView(
            allPermissions: viewModel.allPermissions,
            emptyMessage: "No permission rules configured for this project.",
            onPromoteToGlobal: { rule, type in
                ruleToPromote = RulePromotionInfo(rule: rule, type: type)
                showPromoteConfirmation = true
            },
            onCopyToScope: { rule, type, targetScope in
                Task {
                    do {
                        let added = try await PermissionRuleCopyService.shared.copyRule(
                            rule: rule,
                            type: type,
                            to: targetScope,
                            projectPath: viewModel.projectURL
                        )
                        if added {
                            NotificationManager.shared.showSuccess(
                                "Rule Copied",
                                message: "Copied to \(targetScope.label)"
                            )
                        } else {
                            NotificationManager.shared.showInfo(
                                "Rule Already Exists",
                                message: "This rule already exists in \(targetScope.label)"
                            )
                        }
                        await viewModel.loadConfiguration()
                    } catch {
                        NotificationManager.shared.showError(error)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func tabContent(for tab: ProjectDetailTab) -> some View {
        switch tab {
        case .permissions:
            permissionsTabContent
        case .environment:
            EnvironmentTabView(
                envVars: viewModel.allEnvironmentVariables,
                emptyMessage: "No environment variables configured for this project."
            )
        case .mcpServers:
            MCPServersTabView(
                servers: viewModel.allMCPServers,
                emptyMessage: "No MCP servers configured for this project.",
                projectPath: viewModel.projectURL,
                onAdd: {
                    mcpEditorViewModel = MCPServerEditorViewModel.forAdding(
                        projectPath: viewModel.projectURL,
                        defaultScope: .project
                    )
                    showMCPServerEditor = true
                },
                onEdit: { name, server, source in
                    let scope: MCPServerScope = source == .global ? .global : .project
                    mcpEditorViewModel = MCPServerEditorViewModel.forEditing(
                        name: name,
                        server: server,
                        scope: scope,
                        projectPath: viewModel.projectURL
                    )
                    showMCPServerEditor = true
                },
                onDelete: { name, source in
                    serverToDelete = (name, source)
                    showDeleteConfirmation = true
                },
                onCopy: { name, server in
                    let sourceDestination = CopyDestination.project(
                        path: viewModel.projectPath,
                        name: viewModel.projectName
                    )
                    copyViewModel = MCPCopyViewModel(
                        serverName: name,
                        server: server,
                        sourceDestination: sourceDestination
                    )
                    showCopySheet = true
                }
            )
        case .hooks:
            HooksTabView(
                globalHooks: viewModel.globalSettings?.hooks,
                projectHooks: viewModel.projectSettings?.hooks,
                localHooks: viewModel.projectLocalSettings?.hooks
            )
        case .effectiveConfig:
            if let merged = viewModel.mergedSettings {
                EffectiveConfigView(
                    mergedSettings: merged,
                    envOverrides: viewModel.envOverrides
                )
            } else {
                ContentUnavailableView(
                    "No Configuration",
                    systemImage: "checkmark.rectangle.stack",
                    description: Text("No merged configuration available.")
                )
            }
        case .advanced:
            AdvancedTabView(viewModel: viewModel)
        }
    }
}

// MARK: - ProjectHeaderView

/// Header view showing project metadata.
struct ProjectHeaderView: View {
    // MARK: Internal

    @Bindable var viewModel: ProjectDetailViewModel
    var onExport: (() -> Void)?
    var onImport: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Project icon
                Image(systemName: viewModel.projectExists ? "folder.fill" : "folder.badge.questionmark")
                    .font(.title)
                    .foregroundStyle(viewModel.projectExists ? .blue : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.projectName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Button {
                        viewModel.revealInFinder()
                    } label: {
                        Text(abbreviatePath(viewModel.projectPath))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.projectExists)
                    .onHover { isHovered in
                        if isHovered, viewModel.projectExists {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        viewModel.revealInFinder()
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                    .disabled(!viewModel.projectExists)

                    Button {
                        viewModel.openInTerminal()
                    } label: {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .disabled(!viewModel.projectExists)

                    // Export/Import menu
                    Menu {
                        Button {
                            onExport?()
                        } label: {
                            Label("Export Configuration...", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            onImport?()
                        } label: {
                            Label("Import Configuration...", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .disabled(!viewModel.projectExists)
                }
            }

            // Config file status badges
            HStack(spacing: 8) {
                if let status = viewModel.projectSettingsStatus {
                    ConfigFileBadge(
                        label: "settings.json",
                        status: status,
                        source: .projectShared
                    )
                }
                if let status = viewModel.projectLocalSettingsStatus {
                    ConfigFileBadge(
                        label: "settings.local.json",
                        status: status,
                        source: .projectLocal
                    )
                }
                if let status = viewModel.mcpConfigStatus {
                    ConfigFileBadge(
                        label: ".mcp.json",
                        status: status,
                        source: .projectShared
                    )
                }
            }
        }
        .padding()
    }

    // MARK: Private

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - ConfigFileBadge

/// Badge showing config file status with source color.
struct ConfigFileBadge: View {
    // MARK: Internal

    let label: String
    let status: ConfigFileStatus
    let source: ConfigSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.exists ? "checkmark.circle.fill" : "plus.circle.dashed")
                .foregroundStyle(status.exists ? .green : .secondary)
                .font(.caption)
            Text(label)
                .font(.caption)
            Image(systemName: source.icon)
                .foregroundStyle(sourceColor)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .help(status.exists ? "File exists" : "File not created yet")
    }

    // MARK: Private

    private var sourceColor: Color {
        switch source {
        case .global:
            .blue
        case .projectShared:
            .purple
        case .projectLocal:
            .orange
        }
    }
}

// MARK: - AdvancedTabView

/// Advanced settings tab for a project.
struct AdvancedTabView: View {
    @Bindable var viewModel: ProjectDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project entry info
                if let entry = viewModel.projectEntry {
                    GroupBox("Project Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Trust Dialog Accepted")
                                Spacer()
                                Image(systemName: entry.hasTrustDialogAccepted == true
                                    ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(entry.hasTrustDialogAccepted == true ? .green : .secondary)
                            }

                            if let tools = entry.allowedTools, !tools.isEmpty {
                                Divider()
                                Text("Allowed Tools")
                                    .font(.headline)
                                FlowLayout(spacing: 4) {
                                    ForEach(tools, id: \.self) { tool in
                                        Text(tool)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }

                            if let history = entry.history, !history.isEmpty {
                                Divider()
                                HStack {
                                    Text("Conversation History")
                                    Spacer()
                                    Text("\(history.count) conversations")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Attribution settings
                GroupBox("Attribution") {
                    if let (attribution, source) = viewModel.attributionSettings {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SourceBadge(source: source)
                                Spacer()
                            }
                            AttributionRow(
                                label: "Commit Attribution",
                                enabled: attribution.commits ?? false
                            )
                            AttributionRow(
                                label: "Pull Request Attribution",
                                enabled: attribution.pullRequests ?? false
                            )
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Using default attribution settings.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Disallowed tools
                GroupBox("Disallowed Tools") {
                    let tools = viewModel.allDisallowedTools
                    if tools.isEmpty {
                        Text("No tools are disallowed for this project.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(tools.enumerated()), id: \.offset) { _, item in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(item.tool)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    SourceBadge(source: item.source)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - FlowLayout

/// A simple flow layout for wrapping items.
struct FlowLayout: Layout {
    // MARK: Internal

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    // MARK: Private

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    ProjectDetailView(projectPath: "/Users/test/project")
        .frame(width: 700, height: 500)
}
