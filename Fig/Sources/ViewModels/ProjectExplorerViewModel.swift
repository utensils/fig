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
            favoriteProjectPaths = Set(favorites)
        }
        if let recents = UserDefaults.standard.array(forKey: Self.recentsKey) as? [String] {
            recentProjectPaths = recents
        }
    }

    /// Adds a project to favorites.
    func addFavorite(_ path: String) {
        favoriteProjectPaths.insert(path)
        save()
    }

    /// Removes a project from favorites.
    func removeFavorite(_ path: String) {
        favoriteProjectPaths.remove(path)
        save()
    }

    /// Toggles a project's favorite status.
    func toggleFavorite(_ path: String) {
        if favoriteProjectPaths.contains(path) {
            removeFavorite(path)
        } else {
            addFavorite(path)
        }
    }

    /// Checks if a project is a favorite.
    func isFavorite(_ path: String) -> Bool {
        favoriteProjectPaths.contains(path)
    }

    /// Records a project as recently opened.
    func recordRecentProject(_ path: String) {
        // Remove if already present
        recentProjectPaths.removeAll { $0 == path }
        // Insert at beginning
        recentProjectPaths.insert(path, at: 0)
        // Trim to max
        if recentProjectPaths.count > maxRecentProjects {
            recentProjectPaths = Array(recentProjectPaths.prefix(maxRecentProjects))
        }
        save()
    }

    // MARK: Private

    private static let favoritesKey = "favoriteProjects"
    private static let recentsKey = "recentProjects"

    private func save() {
        UserDefaults.standard.set(Array(favoriteProjectPaths), forKey: Self.favoritesKey)
        UserDefaults.standard.set(recentProjectPaths, forKey: Self.recentsKey)
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
        favoritesStorage.load()
    }

    // MARK: Internal

    /// Storage for favorites and recents.
    let favoritesStorage = FavoritesStorage()

    /// All discovered projects from the global config.
    private(set) var projects: [ProjectEntry] = []

    /// Whether projects are currently being loaded.
    private(set) var isLoading = false

    /// The current search query for filtering projects.
    var searchQuery = ""

    /// Error message if loading fails.
    private(set) var errorMessage: String?

    /// Whether the quick switcher is shown.
    var isQuickSwitcherPresented = false

    /// Favorite projects.
    var favoriteProjects: [ProjectEntry] {
        projects.filter { project in
            guard let path = project.path else {
                return false
            }
            return favoritesStorage.isFavorite(path)
        }
    }

    /// Recent projects (excluding favorites).
    var recentProjects: [ProjectEntry] {
        let favoritePaths = favoritesStorage.favoriteProjectPaths
        return favoritesStorage.recentProjectPaths.compactMap { path in
            // Skip if it's a favorite
            guard !favoritePaths.contains(path) else {
                return nil
            }
            return projects.first { $0.path == path }
        }
    }

    /// Projects filtered by the current search query, excluding favorites and recents.
    var filteredProjects: [ProjectEntry] {
        let favoritePaths = favoritesStorage.favoriteProjectPaths
        let recentPaths = Set(favoritesStorage.recentProjectPaths)

        let baseProjects = projects.filter { project in
            guard let path = project.path else {
                return true
            }
            return !favoritePaths.contains(path) && !recentPaths.contains(path)
        }

        if searchQuery.isEmpty {
            return baseProjects
        }
        let query = searchQuery.lowercased()
        return baseProjects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
        }
    }

    /// All projects matching the search query (for quick switcher).
    var searchResults: [ProjectEntry] {
        if searchQuery.isEmpty {
            return projects
        }
        let query = searchQuery.lowercased()
        return projects.filter { project in
            let nameMatch = project.name?.lowercased().contains(query) ?? false
            let pathMatch = project.path?.lowercased().contains(query) ?? false
            return nameMatch || pathMatch
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
        isLoading = true
        errorMessage = nil

        do {
            let config = try await configManager.readGlobalConfig()
            projects = config?.allProjects ?? []
            Log.general.info("Loaded \(self.projects.count) projects")
        } catch {
            errorMessage = error.localizedDescription
            Log.general.error("Failed to load projects: \(error.localizedDescription)")
        }

        isLoading = false
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
        favoritesStorage.toggleFavorite(path)
    }

    /// Checks if a project is a favorite.
    func isFavorite(_ project: ProjectEntry) -> Bool {
        guard let path = project.path else {
            return false
        }
        return favoritesStorage.isFavorite(path)
    }

    /// Records a project as recently opened.
    func recordRecentProject(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        favoritesStorage.recordRecentProject(path)
    }

    /// Reveals a project in Finder.
    func revealInFinder(_ project: ProjectEntry) {
        guard let path = project.path else {
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
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

    private let configManager: ConfigFileManager
}
