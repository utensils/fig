import SwiftUI

// MARK: - GlobalSettingsViewModel

/// View model for global settings.
@MainActor
@Observable
final class GlobalSettingsViewModel {
    // MARK: Lifecycle

    init(configManager: ConfigFileManager = .shared) {
        self.configManager = configManager
    }

    // MARK: Internal

    /// Whether data is loading.
    private(set) var isLoading = false

    /// The global settings.
    private(set) var settings: ClaudeSettings?

    /// The global legacy config.
    private(set) var legacyConfig: LegacyConfig?

    /// The selected tab.
    var selectedTab: GlobalSettingsTab = .permissions

    /// Status of the global settings file.
    private(set) var settingsFileStatus: ConfigFileStatus?

    /// Status of the global config file.
    private(set) var configFileStatus: ConfigFileStatus?

    /// Path to the global settings file.
    private(set) var globalSettingsPath: String?

    /// Path to the global settings directory.
    private(set) var globalSettingsDirectoryPath: String?

    /// Global MCP servers from the legacy config.
    var globalMCPServers: [(name: String, server: MCPServer)] {
        self.legacyConfig?.mcpServers?.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 } ?? []
    }

    /// Loads global settings.
    func load() async {
        self.isLoading = true

        do {
            self.settings = try await self.configManager.readGlobalSettings()
            self.legacyConfig = try await self.configManager.readGlobalConfig()

            // Load file statuses
            let settingsURL = await configManager.globalSettingsURL
            self.settingsFileStatus = await ConfigFileStatus(
                exists: self.configManager.fileExists(at: settingsURL),
                url: settingsURL
            )
            self.globalSettingsPath = settingsURL.path
            self.globalSettingsDirectoryPath = await self.configManager.globalSettingsDirectory.path

            let configURL = await configManager.globalConfigURL
            self.configFileStatus = await ConfigFileStatus(
                exists: self.configManager.fileExists(at: configURL),
                url: configURL
            )
        } catch {
            Log.general.error("Failed to load global settings: \(error.localizedDescription)")
        }

        self.isLoading = false
    }

    /// Reveals the settings file in Finder.
    func revealSettingsInFinder() {
        guard let path = globalSettingsPath,
              let dirPath = globalSettingsDirectoryPath
        else {
            return
        }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: dirPath)
    }

    /// Deletes a global MCP server by name.
    func deleteGlobalMCPServer(name: String) async {
        do {
            guard var config = try await configManager.readGlobalConfig() else { return }
            config.mcpServers?.removeValue(forKey: name)
            try await configManager.writeGlobalConfig(config)
            legacyConfig = config
            NotificationManager.shared.showSuccess(
                "Server deleted",
                message: "'\(name)' removed from global configuration"
            )
        } catch {
            NotificationManager.shared.showError(
                "Delete failed",
                message: error.localizedDescription
            )
        }
    }

    // MARK: Private

    private let configManager: ConfigFileManager
}

// MARK: - GlobalSettingsTab

/// Tabs for global settings view.
enum GlobalSettingsTab: String, CaseIterable, Identifiable, Sendable {
    case permissions
    case environment
    case mcpServers
    case advanced

    // MARK: Internal

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .permissions:
            "Permissions"
        case .environment:
            "Environment"
        case .mcpServers:
            "MCP Servers"
        case .advanced:
            "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .permissions:
            "lock.shield"
        case .environment:
            "list.bullet.rectangle"
        case .mcpServers:
            "server.rack"
        case .advanced:
            "gearshape.2"
        }
    }
}

// MARK: - GlobalSettingsDetailView

/// Detail view for global settings.
struct GlobalSettingsDetailView: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            // Header
            GlobalSettingsHeaderView(viewModel: self.viewModel) {
                showingEditor = true
            }

            Divider()

            // Tab content
            if self.viewModel.isLoading {
                ProgressView("Loading settings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: self.$viewModel.selectedTab) {
                    ForEach(GlobalSettingsTab.allCases) { tab in
                        self.globalTabContent(for: tab)
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
        .focusedSceneValue(\.globalSettingsTab, self.$viewModel.selectedTab)
        .focusedSceneValue(\.addMCPServerAction) {
            mcpEditorViewModel = MCPServerEditorViewModel.forAdding(
                projectPath: nil,
                defaultScope: .global
            )
            showMCPServerEditor = true
        }
        .focusedSceneValue(\.pasteMCPServersAction) {
            showPasteServersSheet()
        }
        .task {
            await self.viewModel.load()
        }
        .sheet(isPresented: $showingEditor) {
            GlobalSettingsEditorView {
                Task {
                    await self.viewModel.load()
                }
            }
        }
        .sheet(isPresented: $showMCPServerEditor, onDismiss: {
            Task { await self.viewModel.load() }
        }) {
            if let editorVM = mcpEditorViewModel {
                MCPServerEditorView(viewModel: editorVM)
            }
        }
        .sheet(isPresented: $showCopySheet, onDismiss: {
            Task { await self.viewModel.load() }
        }) {
            if let copyVM = copyViewModel {
                MCPCopySheet(viewModel: copyVM)
                    .task {
                        let config = try? await ConfigFileManager.shared.readGlobalConfig()
                        let projects = config?.allProjects ?? []
                        copyVM.loadDestinations(projects: projects)
                    }
            }
        }
        .sheet(isPresented: $showPasteSheet, onDismiss: {
            Task { await self.viewModel.load() }
        }) {
            if let pasteVM = pasteViewModel {
                MCPPasteSheet(viewModel: pasteVM)
                    .task {
                        let config = try? await ConfigFileManager.shared.readGlobalConfig()
                        let projects = config?.allProjects ?? []
                        pasteVM.loadDestinations(projects: projects)
                    }
            }
        }
        .alert(
            "Delete Server",
            isPresented: $showDeleteConfirmation,
            presenting: serverToDelete
        ) { name in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteGlobalMCPServer(name: name) }
            }
        } message: { name in
            Text("Are you sure you want to delete '\(name)'? This action cannot be undone.")
        }
        .alert(
            "Sensitive Data Warning",
            isPresented: $showSensitiveCopyAlert,
            presenting: pendingCopyServers
        ) { servers in
            Button("Cancel", role: .cancel) {
                pendingCopyServers = nil
            }
            Button("Copy with Placeholders") {
                copyServersToClipboard(servers, redact: true)
            }
            Button("Copy with Secrets") {
                copyServersToClipboard(servers, redact: false)
            }
        } message: { _ in
            Text(
                "The MCP configuration contains environment variables that may contain "
                    + "secrets (API keys, tokens, etc.). Choose how to copy."
            )
        }
    }

    // MARK: Private

    @State private var viewModel = GlobalSettingsViewModel()
    @State private var showingEditor = false
    @State private var showMCPServerEditor = false
    @State private var mcpEditorViewModel: MCPServerEditorViewModel?
    @State private var showDeleteConfirmation = false
    @State private var serverToDelete: String?
    @State private var showCopySheet = false
    @State private var copyViewModel: MCPCopyViewModel?
    @State private var showPasteSheet = false
    @State private var pasteViewModel: MCPPasteViewModel?
    @State private var showSensitiveCopyAlert = false
    @State private var pendingCopyServers: [String: MCPServer]?

    private func handleCopyAllServers() {
        let serverDict = Dictionary(
            uniqueKeysWithValues: viewModel.globalMCPServers.map { ($0.name, $0.server) }
        )

        guard !serverDict.isEmpty else {
            NotificationManager.shared.showInfo(
                "No servers to copy",
                message: "No global MCP servers to copy."
            )
            return
        }

        Task {
            let hasSensitive = await MCPSharingService.shared.containsSensitiveData(
                servers: serverDict
            )

            if hasSensitive {
                pendingCopyServers = serverDict
                showSensitiveCopyAlert = true
            } else {
                copyServersToClipboard(serverDict, redact: false)
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
            pendingCopyServers = nil
        }
    }

    private func showPasteServersSheet() {
        pasteViewModel = MCPPasteViewModel(currentProject: .global)
        showPasteSheet = true
    }

    @ViewBuilder
    private func globalTabContent(for tab: GlobalSettingsTab) -> some View {
        switch tab {
        case .permissions:
            PermissionsTabView(
                permissions: self.viewModel.settings?.permissions,
                source: .global
            )
        case .environment:
            EnvironmentTabView(
                envVars: self.viewModel.settings?.env?.map { ($0.key, $0.value, ConfigSource.global) } ?? [],
                emptyMessage: "No global environment variables configured."
            )
        case .mcpServers:
            MCPServersTabView(
                servers: self.viewModel.globalMCPServers.map { ($0.name, $0.server, ConfigSource.global) },
                emptyMessage: "No global MCP servers configured.",
                onAdd: {
                    mcpEditorViewModel = MCPServerEditorViewModel.forAdding(
                        projectPath: nil,
                        defaultScope: .global
                    )
                    showMCPServerEditor = true
                },
                onEdit: { name, server, _ in
                    mcpEditorViewModel = MCPServerEditorViewModel.forEditing(
                        name: name,
                        server: server,
                        scope: .global,
                        projectPath: nil
                    )
                    showMCPServerEditor = true
                },
                onDelete: { name, _ in
                    serverToDelete = name
                    showDeleteConfirmation = true
                },
                onCopy: { name, server in
                    copyViewModel = MCPCopyViewModel(
                        serverName: name,
                        server: server,
                        sourceDestination: .global
                    )
                    showCopySheet = true
                },
                onCopyAll: {
                    handleCopyAllServers()
                },
                onPasteServers: {
                    showPasteServersSheet()
                }
            )
        case .advanced:
            GlobalAdvancedTabView(
                settings: self.viewModel.settings,
                legacyConfig: self.viewModel.legacyConfig
            )
        }
    }
}

// MARK: - GlobalSettingsHeaderView

/// Header view for global settings.
struct GlobalSettingsHeaderView: View {
    @Bindable var viewModel: GlobalSettingsViewModel
    var onEditSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Global Settings")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Button {
                        self.viewModel.revealSettingsInFinder()
                    } label: {
                        Text("~/.claude/settings.json")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reveal settings file in Finder")
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }

                Spacer()

                // File status badges
                HStack(spacing: 8) {
                    if let status = viewModel.settingsFileStatus {
                        FileStatusBadge(
                            label: "settings.json",
                            exists: status.exists
                        )
                    }
                    if let status = viewModel.configFileStatus {
                        FileStatusBadge(
                            label: ".claude.json",
                            exists: status.exists
                        )
                    }
                }

                // Edit button
                if let onEditSettings {
                    Button {
                        onEditSettings()
                    } label: {
                        Label("Edit Settings", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}

// MARK: - GlobalAdvancedTabView

/// Advanced settings tab for global settings.
struct GlobalAdvancedTabView: View {
    let settings: ClaudeSettings?
    let legacyConfig: LegacyConfig?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Attribution settings
                GroupBox("Attribution") {
                    if let attribution = settings?.attribution {
                        VStack(alignment: .leading, spacing: 8) {
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
                        Text("No attribution settings configured.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Disallowed tools
                GroupBox("Disallowed Tools") {
                    if let tools = settings?.disallowedTools, !tools.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(tools, id: \.self) { tool in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(tool)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No tools are globally disallowed.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Project count
                GroupBox("Statistics") {
                    HStack {
                        Label(
                            "\(self.legacyConfig?.projects?.count ?? 0) projects",
                            systemImage: "folder"
                        )
                        Spacer()
                        Label(
                            "\(self.legacyConfig?.mcpServers?.count ?? 0) global MCP servers",
                            systemImage: "server.rack"
                        )
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - AttributionRow

/// A row showing attribution status.
struct AttributionRow: View {
    let label: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: self.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(self.enabled ? .green : .secondary)
            Text(self.label)
            Spacer()
            Text(self.enabled ? "Enabled" : "Disabled")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FileStatusBadge

/// A badge showing file existence status.
struct FileStatusBadge: View {
    let label: String
    let exists: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: self.exists ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(self.exists ? .green : .orange)
                .font(.caption)
            Text(self.label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(exists ? "file exists" : "file not found")")
    }
}

#Preview {
    GlobalSettingsDetailView()
        .frame(width: 700, height: 500)
}
