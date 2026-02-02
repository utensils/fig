import SwiftUI

// MARK: - SidebarView

/// The sidebar view displaying navigation items and projects.
struct SidebarView: View {
    // MARK: Internal

    @Binding var selection: NavigationSelection?
    @Bindable var viewModel: ProjectExplorerViewModel

    var body: some View {
        List(selection: $selection) {
            // Global Settings Section
            Section("Configuration") {
                Label("Global Settings", systemImage: "globe")
                    .tag(NavigationSelection.globalSettings)
            }

            // Favorites Section
            if !viewModel.favoriteProjects.isEmpty {
                Section("Favorites") {
                    ForEach(viewModel.favoriteProjects) { project in
                        projectRow(for: project, isFavoriteSection: true)
                    }
                }
            }

            // Recents Section
            if !viewModel.recentProjects.isEmpty {
                Section("Recent") {
                    ForEach(viewModel.recentProjects) { project in
                        projectRow(for: project, isFavoriteSection: false)
                    }
                }
            }

            // All Projects Section
            Section {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading projects...")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.filteredProjects.isEmpty, viewModel.favoriteProjects.isEmpty,
                          viewModel.recentProjects.isEmpty
                {
                    if viewModel.searchQuery.isEmpty {
                        ContentUnavailableView(
                            "No Projects Found",
                            systemImage: "folder.badge.questionmark",
                            description: Text(
                                "Claude Code projects will appear here once you use Claude Code in a directory."
                            )
                        )
                    } else {
                        ContentUnavailableView.search(text: viewModel.searchQuery)
                    }
                } else if viewModel.filteredProjects.isEmpty, !viewModel.searchQuery.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                } else {
                    ForEach(viewModel.filteredProjects) { project in
                        projectRow(for: project, isFavoriteSection: false)
                    }
                }
            } header: {
                HStack {
                    Text("Projects")
                    Spacer()
                    if !viewModel.projects.isEmpty {
                        Text("\(viewModel.filteredProjects.count)")
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
            text: $viewModel.searchQuery,
            placement: .sidebar,
            prompt: "Filter projects"
        )
        .navigationTitle("Fig")
        .frame(minWidth: 220)
        .task {
            await viewModel.loadProjects()
        }
        .onChange(of: selection) { _, newValue in
            // Record as recent when selecting a project
            if case let .project(path) = newValue {
                if let project = viewModel.projects.first(where: { $0.path == path }) {
                    viewModel.recordRecentProject(project)
                }
            }
        }
        .sheet(isPresented: $viewModel.isQuickSwitcherPresented) {
            QuickSwitcherView(viewModel: viewModel, selection: $selection)
        }
        .keyboardShortcut("k", modifiers: .command)
    }

    // MARK: Private

    private func projectRow(for project: ProjectEntry, isFavoriteSection: Bool) -> some View {
        ProjectRowView(
            project: project,
            exists: viewModel.projectExists(project),
            mcpCount: viewModel.mcpServerCount(for: project),
            isFavorite: viewModel.isFavorite(project)
        )
        .tag(NavigationSelection.project(project.path ?? ""))
        .contextMenu {
            Button {
                viewModel.toggleFavorite(project)
            } label: {
                if viewModel.isFavorite(project) {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }

            Divider()

            Button {
                viewModel.revealInFinder(project)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .disabled(!viewModel.projectExists(project))

            Button {
                viewModel.openInTerminal(project)
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            .disabled(!viewModel.projectExists(project))
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
            Image(systemName: exists ? "folder.fill" : "folder.badge.questionmark")
                .foregroundStyle(exists ? .blue : .orange)
                .frame(width: 20)

            // Project info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(project.name ?? "Unknown")
                        .font(.body)
                        .foregroundStyle(exists ? .primary : .secondary)
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }

                if let path = project.path {
                    Text(abbreviatePath(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // MCP server badge
            if mcpCount > 0 {
                Text("\(mcpCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple, in: Capsule())
                    .help("\(mcpCount) MCP server\(mcpCount == 1 ? "" : "s") configured")
            }

            // Missing indicator
            if !exists {
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

                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        selectFirstResult()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
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
                    ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, project in
                        QuickSwitcherRow(
                            project: project,
                            isSelected: index == selectedIndex,
                            isFavorite: viewModel.isFavorite(project)
                        )
                        .onTapGesture {
                            selectProject(project)
                        }
                    }

                    if filteredResults.isEmpty {
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
            searchText = ""
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredResults.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            selectFirstResult()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.isQuickSwitcherPresented = false
            return .handled
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var filteredResults: [ProjectEntry] {
        if searchText.isEmpty {
            // Show favorites first, then recents, then all
            let favorites = viewModel.favoriteProjects
            let recents = viewModel.recentProjects
            let others = viewModel.projects.filter { project in
                guard let path = project.path else {
                    return true
                }
                return !viewModel.favoritesStorage.favoriteProjectPaths.contains(path) &&
                    !viewModel.favoritesStorage.recentProjectPaths.contains(path)
            }
            return favorites + recents + others
        }
        let query = searchText.lowercased()
        return viewModel.projects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
        }
    }

    private func selectFirstResult() {
        guard !filteredResults.isEmpty else {
            return
        }
        let project = filteredResults[min(selectedIndex, filteredResults.count - 1)]
        selectProject(project)
    }

    private func selectProject(_ project: ProjectEntry) {
        if let path = project.path {
            selection = .project(path)
            viewModel.recordRecentProject(project)
        }
        viewModel.isQuickSwitcherPresented = false
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
                    Text(project.name ?? "Unknown")
                        .font(.body)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }

                if let path = project.path {
                    Text(abbreviatePath(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
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
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

            Text(label)
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
