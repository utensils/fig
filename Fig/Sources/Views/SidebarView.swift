import SwiftUI

// MARK: - SidebarView

/// The sidebar view displaying navigation items and projects.
struct SidebarView: View {
    // MARK: Internal

    @Binding var selection: NavigationSelection?
    @Bindable var viewModel: ProjectExplorerViewModel

    var body: some View {
        List(selection: self.$selection) {
            // Global Settings Section
            Section("Configuration") {
                Label("Global Settings", systemImage: "globe")
                    .tag(NavigationSelection.globalSettings)
            }

            // Favorites Section
            if !self.viewModel.favoriteProjects.isEmpty {
                Section("Favorites") {
                    ForEach(self.viewModel.favoriteProjects) { project in
                        self.projectRow(for: project, isFavoriteSection: true)
                    }
                }
            }

            // Recents Section
            if !self.viewModel.recentProjects.isEmpty {
                Section("Recent") {
                    ForEach(self.viewModel.recentProjects) { project in
                        self.projectRow(for: project, isFavoriteSection: false)
                    }
                }
            }

            // All Projects Section
            Section {
                if self.viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading projects...")
                            .foregroundStyle(.secondary)
                    }
                } else if self.viewModel.filteredProjects.isEmpty, self.viewModel.favoriteProjects.isEmpty,
                          self.viewModel.recentProjects.isEmpty
                {
                    if self.viewModel.searchQuery.isEmpty {
                        ContentUnavailableView(
                            "No Projects Found",
                            systemImage: "folder.badge.questionmark",
                            description: Text(
                                "Claude Code projects will appear here once you use Claude Code in a directory."
                            )
                        )
                    } else {
                        ContentUnavailableView.search(text: self.viewModel.searchQuery)
                    }
                } else if self.viewModel.filteredProjects.isEmpty, !self.viewModel.searchQuery.isEmpty {
                    ContentUnavailableView.search(text: self.viewModel.searchQuery)
                } else {
                    ForEach(self.viewModel.filteredProjects) { project in
                        self.projectRow(for: project, isFavoriteSection: false)
                    }
                }
            } header: {
                HStack {
                    Text("Projects")
                    Spacer()
                    if !self.viewModel.projects.isEmpty {
                        Text("\(self.viewModel.filteredProjects.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: self.$viewModel.searchQuery,
            placement: .sidebar,
            prompt: "Filter projects"
        )
        .navigationTitle("Fig")
        .frame(minWidth: 220)
        .task {
            await self.viewModel.loadProjects()
        }
        .onChange(of: self.selection) { _, newValue in
            // Record as recent when selecting a project
            if case let .project(path) = newValue {
                if let project = viewModel.projects.first(where: { $0.path == path }) {
                    self.viewModel.recordRecentProject(project)
                }
            }
        }
        .sheet(isPresented: self.$viewModel.isQuickSwitcherPresented) {
            QuickSwitcherView(viewModel: self.viewModel, selection: self.$selection)
        }
        .keyboardShortcut("k", modifiers: .command)
        .alert(
            "Delete Project",
            isPresented: self.$showDeleteConfirmation,
            presenting: self.projectToDelete
        ) { project in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if case let .project(path) = self.selection, path == project.path {
                        self.selection = nil
                    }
                    await self.viewModel.deleteProject(project)
                }
            }
        } message: { project in
            let name = project.name ?? "this project"
            Text(
                "Are you sure you want to remove '\(name)' from your configuration?" +
                    " The project directory will not be affected."
            )
        }
    }

    // MARK: Private

    @State private var showDeleteConfirmation = false
    @State private var projectToDelete: ProjectEntry?

    private func projectRow(for project: ProjectEntry, isFavoriteSection: Bool) -> some View {
        ProjectRowView(
            project: project,
            exists: self.viewModel.projectExists(project),
            mcpCount: self.viewModel.mcpServerCount(for: project),
            isFavorite: self.viewModel.isFavorite(project)
        )
        .tag(NavigationSelection.project(project.path ?? ""))
        .contextMenu {
            Button {
                self.viewModel.toggleFavorite(project)
            } label: {
                if self.viewModel.isFavorite(project) {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }

            Divider()

            Button {
                self.viewModel.revealInFinder(project)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .disabled(!self.viewModel.projectExists(project))

            Button {
                self.viewModel.openInTerminal(project)
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            .disabled(!self.viewModel.projectExists(project))

            Divider()

            Button(role: .destructive) {
                self.projectToDelete = project
                self.showDeleteConfirmation = true
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}

// MARK: - ProjectRowView

/// A row in the sidebar representing a single project.
struct ProjectRowView: View {
    // MARK: Internal

    let project: ProjectEntry
    let exists: Bool
    let mcpCount: Int
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Project icon with status
            Image(systemName: self.exists ? "folder.fill" : "folder.badge.questionmark")
                .foregroundStyle(self.exists ? .blue : .orange)
                .frame(width: 20)

            // Project info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(self.project.name ?? "Unknown")
                        .font(.body)
                        .foregroundStyle(self.exists ? .primary : .secondary)
                        .lineLimit(1)

                    if self.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }

                if let path = project.path {
                    Text(self.abbreviatePath(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // MCP server badge
            if self.mcpCount > 0 {
                Text("\(self.mcpCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple, in: Capsule())
                    .help("\(self.mcpCount) MCP server\(self.mcpCount == 1 ? "" : "s") configured")
            }

            // Missing indicator
            if !self.exists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("Project directory not found")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Private

    /// Abbreviates a path by replacing the home directory with ~.
    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - QuickSwitcherView

/// A quick switcher sheet for rapidly navigating to projects.
struct QuickSwitcherView: View {
    // MARK: Internal

    @Bindable var viewModel: ProjectExplorerViewModel
    @Binding var selection: NavigationSelection?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search projects...", text: self.$searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        self.selectFirstResult()
                    }

                if !self.searchText.isEmpty {
                    Button {
                        self.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            // Results list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(self.filteredResults.enumerated()), id: \.element.id) { index, project in
                        QuickSwitcherRow(
                            project: project,
                            isSelected: index == self.selectedIndex,
                            isFavorite: self.viewModel.isFavorite(project)
                        )
                        .onTapGesture {
                            self.selectProject(project)
                        }
                    }

                    if self.filteredResults.isEmpty {
                        Text("No projects found")
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Keyboard hints
            HStack {
                KeyboardHint(key: "↑↓", label: "Navigate")
                KeyboardHint(key: "↵", label: "Open")
                KeyboardHint(key: "esc", label: "Close")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5))
        }
        .frame(width: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            self.searchText = ""
            self.selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if self.selectedIndex > 0 {
                self.selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if self.selectedIndex < self.filteredResults.count - 1 {
                self.selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            self.selectFirstResult()
            return .handled
        }
        .onKeyPress(.escape) {
            self.viewModel.isQuickSwitcherPresented = false
            return .handled
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var filteredResults: [ProjectEntry] {
        if self.searchText.isEmpty {
            // Show favorites first, then recents, then all
            let favorites = self.viewModel.favoriteProjects
            let recents = self.viewModel.recentProjects
            let others = self.viewModel.projects.filter { project in
                guard let path = project.path else {
                    return true
                }
                return !self.viewModel.favoritesStorage.favoriteProjectPaths.contains(path) &&
                    !self.viewModel.favoritesStorage.recentProjectPaths.contains(path)
            }
            return favorites + recents + others
        }
        let query = self.searchText.lowercased()
        return self.viewModel.projects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
        }
    }

    private func selectFirstResult() {
        guard !self.filteredResults.isEmpty else {
            return
        }
        let project = self.filteredResults[min(self.selectedIndex, self.filteredResults.count - 1)]
        self.selectProject(project)
    }

    private func selectProject(_ project: ProjectEntry) {
        if let path = project.path {
            self.selection = .project(path)
            self.viewModel.recordRecentProject(project)
        }
        self.viewModel.isQuickSwitcherPresented = false
    }
}

// MARK: - QuickSwitcherRow

/// A row in the quick switcher results.
struct QuickSwitcherRow: View {
    // MARK: Internal

    let project: ProjectEntry
    let isSelected: Bool
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(self.project.name ?? "Unknown")
                        .font(.body)

                    if self.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }

                if let path = project.path {
                    Text(self.abbreviatePath(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(self.isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
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

// MARK: - KeyboardHint

/// A small keyboard hint label.
struct KeyboardHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(self.key)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

            Text(self.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let viewModel = ProjectExplorerViewModel()
    return NavigationSplitView {
        SidebarView(
            selection: .constant(.globalSettings),
            viewModel: viewModel
        )
    } detail: {
        Text("Detail View")
    }
}

#Preview("Quick Switcher") {
    let viewModel = ProjectExplorerViewModel()
    return QuickSwitcherView(viewModel: viewModel, selection: .constant(nil))
        .padding()
}
