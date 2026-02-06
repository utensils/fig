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
                viewModel: self.viewModel,
                onExport: {
                    self.exportViewModel = ConfigExportViewModel(
                        projectPath: self.viewModel.projectURL,
                        projectName: self.viewModel.projectName
                    )
                    self.showExportSheet = true
                },
                onImport: {
                    self.importViewModel = ConfigImportViewModel(
                        projectPath: self.viewModel.projectURL,
                        projectName: self.viewModel.projectName
                    )
                    self.showImportSheet = true
                },
                onImportFromJSON: {
                    self.showPasteServersSheet()
                },
                onExportMCPJSON: {
                    self.exportMCPJSON()
                }
            )

            Divider()

            // Tab content
            if self.viewModel.isLoading {
                ProgressView("Loading configuration...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !self.viewModel.projectExists {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text("The project directory no longer exists at:\n\(self.viewModel.projectPath)")
                )
            } else {
                TabView(selection: self.$viewModel.selectedTab) {
                    ForEach(ProjectDetailTab.allCases) { tab in
                        self.tabContent(for: tab)
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
        .focusedSceneValue(\.projectDetailTab, self.$viewModel.selectedTab)
        .focusedSceneValue(\.addMCPServerAction) {
            self.mcpEditorViewModel = MCPServerEditorViewModel.forAdding(
                projectPath: self.viewModel.projectURL,
                defaultScope: .project
            )
            self.showMCPServerEditor = true
        }
        .task {
            await self.viewModel.loadConfiguration()
        }
        .sheet(isPresented: self.$showMCPServerEditor, onDismiss: {
            Task {
                await self.viewModel.loadConfiguration()
            }
        }) {
            if let editorViewModel = mcpEditorViewModel {
                MCPServerEditorView(viewModel: editorViewModel)
            }
        }
        .alert(
            "Delete Server",
            isPresented: self.$showDeleteConfirmation,
            presenting: self.serverToDelete
        ) { server in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await self.viewModel.deleteMCPServer(name: server.name, source: server.source)
                }
            }
        } message: { server in
            Text("Are you sure you want to delete '\(server.name)'? This action cannot be undone.")
        }
        .sheet(isPresented: self.$showCopySheet, onDismiss: {
            Task {
                await self.viewModel.loadConfiguration()
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
        .sheet(isPresented: self.$showExportSheet) {
            if let exportVM = exportViewModel {
                ConfigExportView(viewModel: exportVM)
            }
        }
        .sheet(isPresented: self.$showImportSheet, onDismiss: {
            Task {
                await self.viewModel.loadConfiguration()
            }
        }) {
            if let importVM = importViewModel {
                ConfigImportView(viewModel: importVM)
            }
        }
        .promoteToGlobalAlert(
            isPresented: self.$showPromoteConfirmation,
            ruleToPromote: self.$ruleToPromote,
            projectURL: self.viewModel.projectURL,
            onComplete: { await self.viewModel.loadConfiguration() }
        )
        .sheet(item: self.$pasteViewModel, onDismiss: {
            Task {
                await self.viewModel.loadConfiguration()
            }
        }) { pasteVM in
            MCPPasteSheet(viewModel: pasteVM)
                .task {
                    let config = try? await ConfigFileManager.shared.readGlobalConfig()
                    let projects = config?.allProjects ?? []
                    pasteVM.loadDestinations(projects: projects)
                }
        }
        .alert(
            "Sensitive Data Warning",
            isPresented: self.$showSensitiveCopyAlert,
            presenting: self.pendingCopyServers
        ) { servers in
            Button("Cancel", role: .cancel) {
                self.pendingCopyServers = nil
            }
            Button("Copy with Placeholders") {
                self.copyServersToClipboard(servers, redact: true)
            }
            Button("Copy with Secrets") {
                self.copyServersToClipboard(servers, redact: false)
            }
        } message: { _ in
            Text(
                "The MCP configuration contains environment variables that may contain "
                    + "secrets (API keys, tokens, etc.). Choose how to copy."
            )
        }
        .focusedSceneValue(\.pasteMCPServersAction) {
            self.showPasteServersSheet()
        }
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
    @State private var pasteViewModel: MCPPasteViewModel?
    @State private var showSensitiveCopyAlert = false
    @State private var pendingCopyServers: [String: MCPServer]?

    private var permissionsTabContent: some View {
        PermissionsTabView(
            allPermissions: self.viewModel.allPermissions,
            emptyMessage: "No permission rules configured for this project.",
            onPromoteToGlobal: { rule, type in
                self.ruleToPromote = RulePromotionInfo(rule: rule, type: type)
                self.showPromoteConfirmation = true
            },
            onCopyToScope: { rule, type, targetScope in
                Task {
                    do {
                        let added = try await PermissionRuleCopyService.shared.copyRule(
                            rule: rule,
                            type: type,
                            to: targetScope,
                            projectPath: self.viewModel.projectURL
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
                        await self.viewModel.loadConfiguration()
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
            self.permissionsTabContent
        case .environment:
            EnvironmentTabView(
                envVars: self.viewModel.allEnvironmentVariables,
                emptyMessage: "No environment variables configured for this project."
            )
        case .mcpServers:
            MCPServersTabView(
                servers: self.viewModel.allMCPServers,
                emptyMessage: "No MCP servers configured for this project.",
                projectPath: self.viewModel.projectURL,
                onAdd: {
                    self.mcpEditorViewModel = MCPServerEditorViewModel.forAdding(
                        projectPath: self.viewModel.projectURL,
                        defaultScope: .project
                    )
                    self.showMCPServerEditor = true
                },
                onEdit: { name, server, source in
                    let scope: MCPServerScope = source == .global ? .global : .project
                    self.mcpEditorViewModel = MCPServerEditorViewModel.forEditing(
                        name: name,
                        server: server,
                        scope: scope,
                        projectPath: self.viewModel.projectURL
                    )
                    self.showMCPServerEditor = true
                },
                onDelete: { name, source in
                    self.serverToDelete = (name, source)
                    self.showDeleteConfirmation = true
                },
                onCopy: { name, server in
                    let sourceDestination = CopyDestination.project(
                        path: self.viewModel.projectPath,
                        name: self.viewModel.projectName
                    )
                    self.copyViewModel = MCPCopyViewModel(
                        serverName: name,
                        server: server,
                        sourceDestination: sourceDestination
                    )
                    self.showCopySheet = true
                },
                onCopyAll: {
                    self.handleCopyAllServers()
                },
                onPasteServers: {
                    self.showPasteServersSheet()
                }
            )
        case .hooks:
            HooksTabView(
                globalHooks: self.viewModel.globalSettings?.hooks,
                projectHooks: self.viewModel.projectSettings?.hooks,
                localHooks: self.viewModel.projectLocalSettings?.hooks
            )
        case .claudeMD:
            ClaudeMDView(projectPath: self.viewModel.projectPath)
        case .effectiveConfig:
            if let merged = viewModel.mergedSettings {
                EffectiveConfigView(
                    mergedSettings: merged,
                    envOverrides: self.viewModel.envOverrides
                )
            } else {
                ContentUnavailableView(
                    "No Configuration",
                    systemImage: "checkmark.rectangle.stack",
                    description: Text("No merged configuration available.")
                )
            }
        case .healthCheck:
            ConfigHealthCheckView(viewModel: self.viewModel)
        case .advanced:
            AdvancedTabView(viewModel: self.viewModel)
        }
    }

    private func handleCopyAllServers() {
        let serverDict = Dictionary(
            uniqueKeysWithValues: viewModel.allMCPServers.map { ($0.name, $0.server) }
        )

        guard !serverDict.isEmpty else {
            NotificationManager.shared.showInfo(
                "No servers to copy",
                message: "No MCP servers configured for this project."
            )
            return
        }

        Task {
            let hasSensitive = await MCPSharingService.shared.containsSensitiveData(
                servers: serverDict
            )

            if hasSensitive {
                self.pendingCopyServers = serverDict
                self.showSensitiveCopyAlert = true
            } else {
                self.copyServersToClipboard(serverDict, redact: false)
            }
        }
    }

    private func copyServersToClipboard(_ servers: [String: MCPServer], redact: Bool) {
        Task {
            do {
                try MCPSharingService.shared.writeToClipboard(
                    servers: servers,
                    redactSensitive: redact
                )
                let message = redact
                    ? "\(servers.count) server(s) copied with placeholders"
                    : "\(servers.count) server(s) copied to clipboard"
                NotificationManager.shared.showSuccess("Copied to clipboard", message: message)
            } catch {
                NotificationManager.shared.showError(
                    "Copy failed",
                    message: error.localizedDescription
                )
            }
            self.pendingCopyServers = nil
        }
    }

    private func showPasteServersSheet() {
        let currentProject = CopyDestination.project(
            path: self.viewModel.projectPath,
            name: self.viewModel.projectName
        )
        self.pasteViewModel = MCPPasteViewModel(currentProject: currentProject)
    }

    private func exportMCPJSON() {
        let projectServers = self.viewModel.allMCPServers
            .filter { $0.source != .global }
        let serverDict = Dictionary(
            uniqueKeysWithValues: projectServers.map { ($0.name, $0.server) }
        )

        guard !serverDict.isEmpty else {
            NotificationManager.shared.showInfo(
                "No servers to export",
                message: "This project has no project-level MCP servers to export."
            )
            return
        }

        Task {
            do {
                let config = MCPConfig(mcpServers: serverDict)
                try await ConfigFileManager.shared.writeMCPConfig(
                    config,
                    for: self.viewModel.projectURL
                )
                NotificationManager.shared.showSuccess(
                    "Exported .mcp.json",
                    message: "MCP configuration written to project root"
                )
                await self.viewModel.loadConfiguration()
            } catch {
                NotificationManager.shared.showError(
                    "Export failed",
                    message: error.localizedDescription
                )
            }
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
    var onImportFromJSON: (() -> Void)?
    var onExportMCPJSON: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Project icon
                Image(systemName: self.viewModel.projectExists ? "folder.fill" : "folder.badge.questionmark")
                    .font(.title)
                    .foregroundStyle(self.viewModel.projectExists ? .blue : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.viewModel.projectName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Button {
                        self.viewModel.revealInFinder()
                    } label: {
                        Text(self.abbreviatePath(self.viewModel.projectPath))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.viewModel.projectExists)
                    .onHover { isHovered in
                        if isHovered, self.viewModel.projectExists {
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
                        self.viewModel.revealInFinder()
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                    .disabled(!self.viewModel.projectExists)
                    .accessibilityLabel("Reveal in Finder")
                    .accessibilityHint("Opens the project directory in Finder")

                    Button {
                        self.viewModel.openInTerminal()
                    } label: {
                        Label("Terminal", systemImage: "terminal")
                    }
                    .disabled(!self.viewModel.projectExists)
                    .accessibilityLabel("Open in Terminal")
                    .accessibilityHint("Opens a Terminal window at the project directory")

                    // Export/Import menu
                    Menu {
                        Button {
                            self.onExport?()
                        } label: {
                            Label("Export Configuration...", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            self.onImport?()
                        } label: {
                            Label("Import Configuration...", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button {
                            self.onImportFromJSON?()
                        } label: {
                            Label("Import MCP Servers from JSON...", systemImage: "doc.on.clipboard")
                        }

                        Button {
                            self.onExportMCPJSON?()
                        } label: {
                            Label("Export .mcp.json...", systemImage: "doc.badge.arrow.up")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .disabled(!self.viewModel.projectExists)
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
            Image(systemName: self.status.exists ? "checkmark.circle.fill" : "plus.circle.dashed")
                .foregroundStyle(self.status.exists ? .green : .secondary)
                .font(.caption)
            Text(self.label)
                .font(.caption)
            Image(systemName: self.source.icon)
                .foregroundStyle(self.sourceColor)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .help(self.status.exists ? "File exists" : "File not created yet")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.label), \(self.status.exists ? "file exists" : "file not created yet")")
    }

    // MARK: Private

    private var sourceColor: Color {
        switch self.source {
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
                    let tools = self.viewModel.allDisallowedTools
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
        let result = self.layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = self.layout(proposal: proposal, subviews: subviews)
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
                currentY += lineHeight + self.spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + self.spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    ProjectDetailView(projectPath: "/Users/test/project")
        .frame(width: 700, height: 500)
}
