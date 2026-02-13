import AppKit
import Foundation
import OSLog
import SwiftUI

// MARK: - FavoritesStorage

/// Handles persistence of favorite and recent projects.
@MainActor
@Observable
final class FavoritesStorage {
    // MARK: Internal

    /// Set of favorite project paths.
    private(set) var favoriteProjectPaths: Set<String> = []

    /// List of recently opened project paths (most recent first).
    private(set) var recentProjectPaths: [String] = []

    /// Maximum number of recent projects to track.
    let maxRecentProjects = 10

    /// Loads favorites and recents from UserDefaults.
    func load() {
        if let favorites = UserDefaults.standard.array(forKey: Self.favoritesKey) as? [String] {
            self.favoriteProjectPaths = Set(favorites)
        }
        if let recents = UserDefaults.standard.array(forKey: Self.recentsKey) as? [String] {
            self.recentProjectPaths = recents
        }
    }

    /// Adds a project to favorites.
    func addFavorite(_ path: String) {
        self.favoriteProjectPaths.insert(path)
        self.save()
    }

    /// Removes a project from favorites.
    func removeFavorite(_ path: String) {
        self.favoriteProjectPaths.remove(path)
        self.save()
    }

    /// Toggles a project's favorite status.
    func toggleFavorite(_ path: String) {
        if self.favoriteProjectPaths.contains(path) {
            self.removeFavorite(path)
        } else {
            self.addFavorite(path)
        }
    }

    /// Checks if a project is a favorite.
    func isFavorite(_ path: String) -> Bool {
        self.favoriteProjectPaths.contains(path)
    }

    /// Records a project as recently opened.
    func recordRecentProject(_ path: String) {
        // Remove if already present
        self.recentProjectPaths.removeAll { $0 == path }
        // Insert at beginning
        self.recentProjectPaths.insert(path, at: 0)
        // Trim to max
        if self.recentProjectPaths.count > self.maxRecentProjects {
            self.recentProjectPaths = Array(self.recentProjectPaths.prefix(self.maxRecentProjects))
        }
        self.save()
    }

    /// Removes a project from both favorites and recents.
    func removeProject(_ path: String) {
        self.favoriteProjectPaths.remove(path)
        self.recentProjectPaths.removeAll { $0 == path }
        self.save()
    }

    // MARK: Private

    private static let favoritesKey = "favoriteProjects"
    private static let recentsKey = "recentProjects"

    private func save() {
        UserDefaults.standard.set(Array(self.favoriteProjectPaths), forKey: Self.favoritesKey)
        UserDefaults.standard.set(self.recentProjectPaths, forKey: Self.recentsKey)
    }
}

// MARK: - ProjectExplorerViewModel

/// View model for the project explorer, managing project discovery and selection.
@MainActor
@Observable
final class ProjectExplorerViewModel {
    // MARK: Lifecycle

    init(configManager: ConfigFileManager = .shared) {
        self.configManager = configManager
        self.isGroupedByParent = UserDefaults.standard.bool(forKey: Self.groupByParentKey)
        self.favoritesStorage.load()
    }

    // MARK: Internal

    /// Storage for favorites and recents.
    let favoritesStorage = FavoritesStorage()

    /// All discovered projects from the global config.
    var projects: [ProjectEntry] = []

    /// Whether projects are currently being loaded.
    private(set) var isLoading = false

    /// The current search query for filtering projects.
    var searchQuery = ""

    /// Error message if loading fails.
    private(set) var errorMessage: String?

    /// Whether the quick switcher is shown.
    var isQuickSwitcherPresented = false

    /// Whether projects are grouped by parent directory in the sidebar.
    var isGroupedByParent: Bool = false {
        didSet {
            UserDefaults.standard.set(self.isGroupedByParent, forKey: Self.groupByParentKey)
        }
    }

    /// All projects whose directories no longer exist on disk.
    var missingProjects: [ProjectEntry] {
        self.projects.filter { !self.projectExists($0) }
    }

    /// Whether there are any missing projects that can be cleaned up.
    var hasMissingProjects: Bool {
        self.projects.contains { !self.projectExists($0) }
    }

    /// Favorite projects.
    var favoriteProjects: [ProjectEntry] {
        self.projects.filter { project in
            guard let path = project.path else {
                return false
            }
            return self.favoritesStorage.isFavorite(path)
        }
    }

    /// Recent projects (excluding favorites).
    var recentProjects: [ProjectEntry] {
        let favoritePaths = self.favoritesStorage.favoriteProjectPaths
        return self.favoritesStorage.recentProjectPaths.compactMap { path in
            // Skip if it's a favorite
            guard !favoritePaths.contains(path) else {
                return nil
            }
            return self.projects.first { $0.path == path }
        }
    }

    /// Projects filtered by the current search query, excluding favorites and recents.
    var filteredProjects: [ProjectEntry] {
        let favoritePaths = self.favoritesStorage.favoriteProjectPaths
        let recentPaths = Set(favoritesStorage.recentProjectPaths)

        let baseProjects = self.projects.filter { project in
            guard let path = project.path else {
                return true
            }
            return !favoritePaths.contains(path) && !recentPaths.contains(path)
        }

        if self.searchQuery.isEmpty {
            return baseProjects
        }
        let query = self.searchQuery.lowercased()
        return baseProjects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
        }
    }

    /// All projects matching the search query (for quick switcher).
    var searchResults: [ProjectEntry] {
        if self.searchQuery.isEmpty {
            return self.projects
        }
        let query = self.searchQuery.lowercased()
        return self.projects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
        }
    }

    /// Projects grouped by their parent directory.
    ///
    /// Groups are sorted alphabetically by parent path.
    /// Projects within each group are sorted by name.
    var groupedProjects: [ProjectGroup] {
        let projects = self.filteredProjects

        var groups: [String: [ProjectEntry]] = [:]
        for project in projects {
            let parentPath = self.parentDirectory(for: project)
            groups[parentPath, default: []].append(project)
        }

        return groups.keys.sorted().map { parentPath in
            ProjectGroup(
                parentPath: parentPath,
                displayName: self.abbreviatePath(parentPath),
                projects: groups[parentPath]?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
            )
        }
    }

    /// Checks if a project directory exists on disk.
    func projectExists(_ project: ProjectEntry) -> Bool {
        guard let path = project.path else {
            return false
        }
        return FileManager.default.fileExists(atPath: path)
    }

    /// Loads projects from the global configuration file.
    func loadProjects() async {
        self.isLoading = true
        self.errorMessage = nil

        do {
            let config = try await self.configManager.readGlobalConfig()
            self.projects = config?.allProjects ?? []
            Log.general.info("Loaded \(self.projects.count) projects")
        } catch {
            self.errorMessage = error.localizedDescription
            Log.general.error("Failed to load projects: \(error.localizedDescription)")
        }

        self.isLoading = false
    }

    /// Returns the MCP server count for a project.
    func mcpServerCount(for project: ProjectEntry) -> Int {
        project.mcpServers?.count ?? 0
    }

    /// Toggles favorite status for a project.
    func toggleFavorite(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        self.favoritesStorage.toggleFavorite(path)
    }

    /// Checks if a project is a favorite.
    func isFavorite(_ project: ProjectEntry) -> Bool {
        guard let path = project.path else {
            return false
        }
        return self.favoritesStorage.isFavorite(path)
    }

    /// Records a project as recently opened.
    func recordRecentProject(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        self.favoritesStorage.recordRecentProject(path)
    }

    /// Reveals a project in Finder.
    func revealInFinder(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    /// Removes a project from the global configuration.
    ///
    /// This removes the project entry from `~/.claude.json` and cleans up
    /// favorites and recents. The project directory itself is not affected.
    ///
    /// - Note: Callers are responsible for clearing any active selection
    ///   referencing this project before invoking this method.
    func deleteProject(_ project: ProjectEntry) async {
        guard let path = project.path else {
            return
        }

        do {
            guard var config = try await configManager.readGlobalConfig() else {
                return
            }
            config.projects?.removeValue(forKey: path)
            try await self.configManager.writeGlobalConfig(config)

            self.projects.removeAll { $0.path == path }
            self.favoritesStorage.removeProject(path)

            NotificationManager.shared.showSuccess(
                "Project removed",
                message: "'\(project.name ?? path)' removed from configuration"
            )
            Log.general.info("Removed project from config: \(path)")
        } catch {
            Log.general.error("Failed to remove project: \(error.localizedDescription)")
            NotificationManager.shared.showError(error)
        }
    }

    /// Removes multiple projects from the global configuration in a single operation.
    ///
    /// This removes the project entries from `~/.claude.json` and cleans up
    /// favorites and recents. The project directories themselves are not affected.
    ///
    /// - Note: Callers are responsible for clearing any active selection
    ///   referencing these projects before invoking this method.
    func deleteProjects(_ projects: [ProjectEntry]) async {
        let paths = projects.compactMap(\.path)
        guard !paths.isEmpty else {
            return
        }

        do {
            guard var config = try await configManager.readGlobalConfig() else {
                return
            }

            for path in paths {
                config.projects?.removeValue(forKey: path)
            }

            try await self.configManager.writeGlobalConfig(config)

            let pathSet = Set(paths)
            self.projects.removeAll { pathSet.contains($0.path ?? "") }
            for path in paths {
                self.favoritesStorage.removeProject(path)
            }

            let count = paths.count
            NotificationManager.shared.showSuccess(
                "\(count) project\(count == 1 ? "" : "s") removed",
                message: "Removed from configuration"
            )
            Log.general.info("Removed \(count) projects from config")
        } catch {
            Log.general.error("Failed to remove projects: \(error.localizedDescription)")
            NotificationManager.shared.showError(error)
        }
    }

    /// Removes all projects whose directories no longer exist on disk.
    ///
    /// This is a convenience method that identifies missing projects and
    /// removes them in a single batch operation using ``deleteProjects(_:)``.
    ///
    /// - Note: Callers are responsible for clearing any active selection
    ///   referencing these projects before invoking this method.
    ///
    /// - Returns: The number of projects removed.
    @discardableResult
    func removeMissingProjects() async -> Int {
        let missing = self.missingProjects
        guard !missing.isEmpty else {
            return 0
        }
        await self.deleteProjects(missing)
        return missing.count
    }

    /// Opens a project in Terminal.
    func openInTerminal(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        let script = """
        tell application "Terminal"
            do script "cd \(path.replacingOccurrences(of: "\"", with: "\\\""))"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                Log.general.error("Failed to open Terminal: \(error)")
            }
        }
    }

    // MARK: Private

    private static let groupByParentKey = "groupProjectsByParent"

    private let configManager: ConfigFileManager

    /// Returns the parent directory path for a project.
    private func parentDirectory(for project: ProjectEntry) -> String {
        guard let path = project.path else {
            return "Unknown"
        }
        return URL(fileURLWithPath: path).deletingLastPathComponent().path
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
