import Foundation

// MARK: - ProjectDiscoveryService

/// Service for discovering Claude Code projects on the user's system.
///
/// Discovers projects from two sources:
/// 1. The `~/.claude.json` legacy config file (projects dictionary)
/// 2. Optional filesystem scanning of common directories
///
/// Example usage:
/// ```swift
/// let service = ProjectDiscoveryService(configManager: ConfigFileManager.shared)
/// let projects = await service.discoverProjects(scanDirectories: true)
/// for project in projects {
///     print("\(project.displayName): \(project.path)")
/// }
/// ```
actor ProjectDiscoveryService {
    // MARK: Lifecycle

    init(
        configManager: ConfigFileManager = .shared,
        fileManager: FileManager = .default
    ) {
        self.configManager = configManager
        self.fileManager = fileManager
    }

    // MARK: Internal

    /// Default directories to scan for Claude projects.
    static let defaultScanDirectories: [String] = [
        "~",
        "~/code",
        "~/Code",
        "~/projects",
        "~/Projects",
        "~/Developer",
        "~/dev",
        "~/src",
        "~/repos",
        "~/github",
        "~/workspace",
    ]

    /// Discovers all Claude Code projects.
    ///
    /// - Parameters:
    ///   - scanDirectories: Whether to scan common directories for `.claude/` folders.
    ///   - directories: Custom directories to scan (defaults to common locations).
    /// - Returns: Array of discovered projects, sorted by last modified (most recent first).
    func discoverProjects(
        scanDirectories: Bool = false,
        directories: [String]? = nil
    ) async throws -> [DiscoveredProject] {
        var allPaths = Set<String>()

        // 1. Discover from legacy config
        let legacyPaths = try await discoverFromLegacyConfig()
        allPaths.formUnion(legacyPaths)

        // 2. Optionally scan directories
        if scanDirectories {
            let dirs = directories ?? Self.defaultScanDirectories
            let scannedPaths = await scanForProjects(in: dirs)
            allPaths.formUnion(scannedPaths)
        }

        // 3. Build discovered project entries
        var projects: [DiscoveredProject] = []
        for path in allPaths {
            if let project = await buildDiscoveredProject(from: path) {
                projects.append(project)
            }
        }

        // 4. Sort by last modified (most recent first)
        return projects.sorted { first, second in
            switch (first.lastModified, second.lastModified) {
            case let (date1?, date2?):
                date1 > date2
            case (nil, _?):
                false
            case (_?, nil):
                true
            case (nil, nil):
                first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
            }
        }
    }

    /// Discovers projects from the legacy config file only.
    ///
    /// - Returns: Array of project paths from `~/.claude.json`.
    func discoverFromLegacyConfig() async throws -> [String] {
        guard let config = try await configManager.readGlobalConfig() else {
            return []
        }

        return config.projectPaths.compactMap { path in
            canonicalizePath(path)
        }
    }

    /// Scans directories for Claude projects (directories containing `.claude/`).
    ///
    /// - Parameter directories: Directories to scan.
    /// - Returns: Array of discovered project paths.
    func scanForProjects(in directories: [String]) async -> [String] {
        var discoveredPaths = Set<String>()

        for directory in directories {
            let expandedPath = expandPath(directory)
            guard let canonicalPath = canonicalizePath(expandedPath) else {
                continue
            }

            let paths = await scanDirectory(canonicalPath, maxDepth: 3)
            discoveredPaths.formUnion(paths)
        }

        return Array(discoveredPaths)
    }

    /// Refreshes project information for a specific path.
    ///
    /// - Parameter path: The project path to refresh.
    /// - Returns: Updated discovered project, or nil if the path is invalid.
    func refreshProject(at path: String) async -> DiscoveredProject? {
        await buildDiscoveredProject(from: path)
    }

    // MARK: Private

    private let configManager: ConfigFileManager
    private let fileManager: FileManager

    /// Builds a DiscoveredProject from a path.
    private func buildDiscoveredProject(from path: String) async -> DiscoveredProject? {
        guard let canonicalPath = canonicalizePath(path) else {
            return nil
        }

        let url = URL(fileURLWithPath: canonicalPath)
        let exists = fileManager.fileExists(atPath: canonicalPath)
        let displayName = url.lastPathComponent

        // Check for config files
        let claudeDir = url.appendingPathComponent(".claude")
        let settingsPath = claudeDir.appendingPathComponent("settings.json").path
        let localSettingsPath = claudeDir.appendingPathComponent("settings.local.json").path
        let mcpConfigPath = url.appendingPathComponent(".mcp.json").path

        let hasSettings = fileManager.fileExists(atPath: settingsPath)
        let hasLocalSettings = fileManager.fileExists(atPath: localSettingsPath)
        let hasMCPConfig = fileManager.fileExists(atPath: mcpConfigPath)

        // Get last modified date
        let lastModified = getLastModifiedDate(for: url)

        return DiscoveredProject(
            path: canonicalPath,
            displayName: displayName,
            exists: exists,
            hasSettings: hasSettings,
            hasLocalSettings: hasLocalSettings,
            hasMCPConfig: hasMCPConfig,
            lastModified: lastModified
        )
    }

    /// Scans a directory for Claude projects.
    private func scanDirectory(_ path: String, maxDepth: Int) async -> [String] {
        guard maxDepth > 0 else {
            return []
        }

        var discoveredPaths: [String] = []
        let url = URL(fileURLWithPath: path)

        // Check if this directory itself is a Claude project
        let claudeDir = url.appendingPathComponent(".claude")
        if fileManager.fileExists(atPath: claudeDir.path) {
            discoveredPaths.append(path)
        }

        // Scan subdirectories
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return discoveredPaths
        }

        for item in contents {
            guard let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  resourceValues.isDirectory == true,
                  resourceValues.isSymbolicLink != true
            else {
                continue
            }

            // Skip common non-project directories
            let name = item.lastPathComponent
            guard !Self.skipDirectories.contains(name) else {
                continue
            }

            let subPaths = await scanDirectory(item.path, maxDepth: maxDepth - 1)
            discoveredPaths.append(contentsOf: subPaths)
        }

        return discoveredPaths
    }

    /// Directories to skip during scanning.
    private static let skipDirectories: Set<String> = [
        "node_modules",
        ".git",
        ".svn",
        ".hg",
        "vendor",
        "Pods",
        ".build",
        "build",
        "dist",
        "target",
        "__pycache__",
        ".venv",
        "venv",
        ".cache",
        "Library",
        "Applications",
    ]

    /// Expands tilde in path.
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let homeDir = fileManager.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: homeDir, options: .anchored)
        }
        return path
    }

    /// Canonicalizes a path by resolving symlinks and standardizing.
    private func canonicalizePath(_ path: String) -> String? {
        let expandedPath = expandPath(path)
        let url = URL(fileURLWithPath: expandedPath)
        let standardized = url.standardized

        // Only return if it's a valid absolute path
        guard standardized.path.hasPrefix("/") else {
            return nil
        }

        return standardized.path
    }

    /// Gets the last modified date for a project.
    private func getLastModifiedDate(for url: URL) -> Date? {
        // Try to get the most recent modification date from config files first
        let configPaths = [
            url.appendingPathComponent(".claude/settings.local.json"),
            url.appendingPathComponent(".claude/settings.json"),
            url.appendingPathComponent(".mcp.json"),
        ]

        var mostRecent: Date?

        for configPath in configPaths {
            if let attrs = try? fileManager.attributesOfItem(atPath: configPath.path),
               let modDate = attrs[.modificationDate] as? Date
            {
                if mostRecent == nil || modDate > mostRecent! {
                    mostRecent = modDate
                }
            }
        }

        // Fall back to directory modification date
        if mostRecent == nil {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date
            {
                mostRecent = modDate
            }
        }

        return mostRecent
    }
}
