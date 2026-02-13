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
                } else if self.viewModel.isGroupedByParent {
                    ForEach(self.viewModel.groupedProjects) { group in
                        DisclosureGroup {
                            ForEach(group.projects) { project in
                                self.projectRow(for: project, isFavoriteSection: false)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(group.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(group.projects.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                    }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !self.viewModel.projects.isEmpty {
                    Button(self.isSelectMode ? "Done" : "Select") {
                        self.toggleSelectMode()
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                if !self.viewModel.projects.isEmpty, !self.isSelectMode {
                    Menu {
                        Toggle(isOn: Binding(
                            get: { self.viewModel.isGroupedByParent },
                            set: { newValue in
                                withAnimation {
                                    self.viewModel.isGroupedByParent = newValue
                                }
                            }
                        )) {
                            Label("Group by Directory", systemImage: "list.bullet.indent")
                        }

                        Divider()

                        Button(role: .destructive) {
                            self.showRemoveMissingConfirmation = true
                        } label: {
                            Label(
                                "Remove Missing Projects\(self.viewModel.hasMissingProjects ? " (\(self.viewModel.missingProjects.count))" : "")",
                                systemImage: "trash.slash"
                            )
                        }
                        .disabled(!self.viewModel.hasMissingProjects)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if self.isSelectMode {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Button {
                            if self.allProjectsSelected {
                                self.selectedProjectPaths.removeAll()
                            } else {
                                self.selectAllProjects()
                            }
                        } label: {
                            Text(self.allProjectsSelected ? "Deselect All" : "Select All")
                        }
                        .buttonStyle(.borderless)

                        if self.viewModel.hasMissingProjects {
                            Button {
                                self.selectMissingProjects()
                            } label: {
                                Text("Select Missing")
                            }
                            .buttonStyle(.borderless)
                        }

                        Spacer()

                        if !self.selectedProjectPaths.isEmpty {
                            Text("\(self.selectedProjectPaths.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Remove") {
                            self.showBulkDeleteConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(self.selectedProjectPaths.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
        }
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
            "Remove Project",
            isPresented: self.$showDeleteConfirmation,
            presenting: self.projectToDelete
        ) { project in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    if case let .project(path) = self.selection, path == project.path {
                        self.selection = nil
                    }
                    if let path = project.path {
                        self.selectedProjectPaths.remove(path)
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
        .alert(
            "Remove \(self.selectedProjectPaths.count) Project\(self.selectedProjectPaths.count == 1 ? "" : "s")",
            isPresented: self.$showBulkDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove \(self.selectedProjectPaths.count)", role: .destructive) {
                Task {
                    if case let .project(path) = self.selection,
                       self.selectedProjectPaths.contains(path)
                    {
                        self.selection = nil
                    }
                    let projectsToDelete = self.viewModel.projects.filter { project in
                        guard let path = project.path else {
                            return false
                        }
                        return self.selectedProjectPaths.contains(path)
                    }
                    await self.viewModel.deleteProjects(projectsToDelete)
                    self.selectedProjectPaths.removeAll()
                    self.isSelectMode = false
                }
            }
        } message: {
            let count = self.selectedProjectPaths.count
            Text(
                "Are you sure you want to remove \(count) project\(count == 1 ? "" : "s") from your configuration?" +
                    " The project directories will not be affected."
            )
        }
        .alert(
            "Remove Missing Projects",
            isPresented: self.$showRemoveMissingConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove \(self.viewModel.missingProjects.count)", role: .destructive) {
                Task {
                    let missingPaths = Set(self.viewModel.missingProjects.compactMap(\.path))
                    if case let .project(path) = self.selection, missingPaths.contains(path) {
                        self.selection = nil
                    }
                    await self.viewModel.removeMissingProjects()
                }
            }
        } message: {
            let count = self.viewModel.missingProjects.count
            Text(
                "\(count) project\(count == 1 ? "" : "s") with missing " +
                    "directories will be removed from your configuration."
            )
        }
    }

    // MARK: Private

    @State private var showDeleteConfirmation = false
    @State private var projectToDelete: ProjectEntry?
    @State private var isSelectMode = false
    @State private var selectedProjectPaths: Set<String> = []
    @State private var showBulkDeleteConfirmation = false
    @State private var showRemoveMissingConfirmation = false

    private var visibleProjectPaths: Set<String> {
        let favorites = self.viewModel.favoriteProjects.compactMap(\.path)
        let recents = self.viewModel.recentProjects.compactMap(\.path)
        let filtered = self.viewModel.filteredProjects.compactMap(\.path)
        return Set(favorites + recents + filtered)
    }

    private var allProjectsSelected: Bool {
        let visible = self.visibleProjectPaths
        return !visible.isEmpty && visible.isSubset(of: self.selectedProjectPaths)
    }

    @ViewBuilder
    private func projectRow(for project: ProjectEntry, isFavoriteSection: Bool) -> some View {
        let content = HStack(spacing: 6) {
            if self.isSelectMode {
                Image(
                    systemName: self.isProjectSelected(project)
                        ? "checkmark.circle.fill" : "circle"
                )
                .foregroundStyle(
                    self.isProjectSelected(project) ? Color.accentColor : .secondary
                )
            }

            ProjectRowView(
                project: project,
                exists: self.viewModel.projectExists(project),
                mcpCount: self.viewModel.mcpServerCount(for: project),
                isFavorite: self.viewModel.isFavorite(project)
            )
        }
        .contentShape(Rectangle())

        if self.isSelectMode {
            content.onTapGesture {
                self.toggleProjectSelection(project)
            }
        } else {
            content
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
                        Label("Remove Project", systemImage: "trash")
                    }
                }
        }
    }

    private func toggleSelectMode() {
        withAnimation {
            self.isSelectMode.toggle()
            if !self.isSelectMode {
                self.selectedProjectPaths.removeAll()
            }
        }
    }

    private func toggleProjectSelection(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        if self.selectedProjectPaths.contains(path) {
            self.selectedProjectPaths.remove(path)
        } else {
            self.selectedProjectPaths.insert(path)
        }
    }

    private func isProjectSelected(_ project: ProjectEntry) -> Bool {
        guard let path = project.path else {
            return false
        }
        return self.selectedProjectPaths.contains(path)
    }

    private func selectAllProjects() {
        self.selectedProjectPaths = self.visibleProjectPaths
    }

    private func selectMissingProjects() {
        let missingPaths = Set(self.viewModel.missingProjects.compactMap(\.path))
        self.selectedProjectPaths = missingPaths.intersection(self.visibleProjectPaths)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityDescription)
    }

    // MARK: Private

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(self.project.name ?? "Unknown project")
        if !self.exists {
            parts.append("directory not found")
        }
        if self.isFavorite {
            parts.append("favorite")
        }
        if self.mcpCount > 0 {
            parts.append("\(self.mcpCount) MCP server\(self.mcpCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.quickSwitcherAccessibilityLabel)
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }

    // MARK: Private

    private var quickSwitcherAccessibilityLabel: String {
        var parts: [String] = [self.project.name ?? "Unknown project"]
        if self.isFavorite {
            parts.append("favorite")
        }
        return parts.joined(separator: ", ")
    }

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
