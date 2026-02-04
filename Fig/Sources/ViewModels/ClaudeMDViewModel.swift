import Foundation
import OSLog

// MARK: - ClaudeMDLevel

/// Represents where a CLAUDE.md file sits in the hierarchy.
enum ClaudeMDLevel: Sendable, Hashable {
    /// Global CLAUDE.md at ~/.claude/CLAUDE.md
    case global
    /// Project root CLAUDE.md
    case projectRoot
    /// Subdirectory CLAUDE.md
    case subdirectory(relativePath: String)

    // MARK: Internal

    var displayName: String {
        switch self {
        case .global:
            "Global"
        case .projectRoot:
            "Project Root"
        case let .subdirectory(relativePath):
            relativePath
        }
    }

    var icon: String {
        switch self {
        case .global:
            "globe"
        case .projectRoot:
            "folder.fill"
        case .subdirectory:
            "folder"
        }
    }

    var sortOrder: Int {
        switch self {
        case .global:
            0
        case .projectRoot:
            1
        case .subdirectory:
            2
        }
    }
}

// MARK: - ClaudeMDFile

/// Represents a single CLAUDE.md file in the hierarchy.
struct ClaudeMDFile: Identifiable, Sendable {
    let id: String
    let url: URL
    let level: ClaudeMDLevel
    var content: String
    var exists: Bool
    var isTrackedByGit: Bool

    var displayPath: String {
        switch level {
        case .global:
            "~/.claude/CLAUDE.md"
        case .projectRoot:
            "CLAUDE.md"
        case let .subdirectory(relativePath):
            "\(relativePath)/CLAUDE.md"
        }
    }
}

// MARK: - ClaudeMDViewModel

/// View model for managing CLAUDE.md files in the project hierarchy.
@MainActor
@Observable
final class ClaudeMDViewModel {
    // MARK: Lifecycle

    init(projectPath: String) {
        self.projectPath = projectPath
        self.projectURL = URL(fileURLWithPath: projectPath)
    }

    // MARK: Internal

    let projectPath: String
    let projectURL: URL

    /// All discovered CLAUDE.md files in the hierarchy.
    private(set) var files: [ClaudeMDFile] = []

    /// Whether files are being loaded.
    private(set) var isLoading = false

    /// The currently selected file ID.
    var selectedFileID: String?

    /// Whether we're in editing mode.
    var isEditing = false

    /// Content being edited.
    var editContent = ""

    /// The currently selected file.
    var selectedFile: ClaudeMDFile? {
        guard let selectedFileID else { return nil }
        return files.first { $0.id == selectedFileID }
    }

    /// Discovers and loads all CLAUDE.md files in the hierarchy.
    func loadFiles() async {
        isLoading = true
        var discovered: [ClaudeMDFile] = []

        // 1. Global CLAUDE.md (~/.claude/CLAUDE.md)
        let globalURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("CLAUDE.md")
        let globalFile = await loadFile(url: globalURL, level: .global)
        discovered.append(globalFile)

        // 2. Project root CLAUDE.md
        let projectRootURL = projectURL.appendingPathComponent("CLAUDE.md")
        let projectFile = await loadFile(url: projectRootURL, level: .projectRoot)
        discovered.append(projectFile)

        // 3. Subdirectory CLAUDE.md files
        let subdirFiles = await discoverSubdirectoryFiles()
        discovered.append(contentsOf: subdirFiles)

        files = discovered

        // Auto-select the first existing file, or the project root
        if selectedFileID == nil {
            let firstExisting = files.first { $0.exists }
            selectedFileID = firstExisting?.id ?? files.first { $0.level == .projectRoot }?.id
        }

        isLoading = false
    }

    /// Saves content to the selected file.
    func saveSelectedFile() async {
        guard let selectedFileID,
              let fileIndex = files.firstIndex(where: { $0.id == selectedFileID })
        else {
            return
        }

        let url = files[fileIndex].url

        do {
            // Ensure parent directory exists
            let parentDir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(
                    at: parentDir,
                    withIntermediateDirectories: true
                )
            }

            try editContent.write(to: url, atomically: true, encoding: .utf8)

            files[fileIndex].content = editContent
            files[fileIndex].exists = true
            files[fileIndex].isTrackedByGit = await checkGitStatus(for: url)

            isEditing = false
            NotificationManager.shared.showSuccess(
                "Saved",
                message: "CLAUDE.md saved successfully"
            )
            Log.fileIO.info("Saved CLAUDE.md at \(url.path)")
        } catch {
            Log.fileIO.error("Failed to save CLAUDE.md: \(error)")
            NotificationManager.shared.showError(error)
        }
    }

    /// Creates a new CLAUDE.md file at the given level.
    func createFile(at level: ClaudeMDLevel) async {
        let url: URL
        switch level {
        case .global:
            url = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude")
                .appendingPathComponent("CLAUDE.md")
        case .projectRoot:
            url = projectURL.appendingPathComponent("CLAUDE.md")
        case let .subdirectory(relativePath):
            url = projectURL
                .appendingPathComponent(relativePath)
                .appendingPathComponent("CLAUDE.md")
        }

        do {
            let parentDir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(
                    at: parentDir,
                    withIntermediateDirectories: true
                )
            }

            let defaultContent = "# CLAUDE.md\n\n"
            try defaultContent.write(to: url, atomically: true, encoding: .utf8)

            await loadFiles()
            selectedFileID = url.path
            editContent = defaultContent
            isEditing = true

            Log.fileIO.info("Created CLAUDE.md at \(url.path)")
        } catch {
            Log.fileIO.error("Failed to create CLAUDE.md: \(error)")
            NotificationManager.shared.showError(error)
        }
    }

    /// Starts editing the selected file.
    func startEditing() {
        guard let selectedFile else { return }
        editContent = selectedFile.content
        isEditing = true
    }

    /// Cancels editing and discards changes.
    func cancelEditing() {
        isEditing = false
        editContent = ""
    }

    /// Reloads the content of the selected file from disk.
    func reloadSelectedFile() async {
        guard let selectedFileID,
              let fileIndex = files.firstIndex(where: { $0.id == selectedFileID })
        else {
            return
        }

        let url = files[fileIndex].url
        let reloaded = await loadFile(url: url, level: files[fileIndex].level)
        files[fileIndex] = reloaded

        if isEditing {
            editContent = reloaded.content
        }
    }

    // MARK: Private

    /// Directories to skip when scanning for subdirectory CLAUDE.md files.
    private static let skipDirectories: Set<String> = [
        ".git", ".svn", ".hg",
        "node_modules", ".build", "build", "dist", "DerivedData",
        ".venv", "venv", "__pycache__", ".tox",
        "Pods", "Carthage",
        ".next", ".nuxt",
        "vendor", "target"
    ]

    private func loadFile(url: URL, level: ClaudeMDLevel) async -> ClaudeMDFile {
        let exists = FileManager.default.fileExists(atPath: url.path)
        var content = ""
        var isTracked = false

        if exists {
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            isTracked = await checkGitStatus(for: url)
        }

        return ClaudeMDFile(
            id: url.path,
            url: url,
            level: level,
            content: content,
            exists: exists,
            isTrackedByGit: isTracked
        )
    }

    private func discoverSubdirectoryFiles() async -> [ClaudeMDFile] {
        let projectURL = self.projectURL
        let skipDirs = Self.skipDirectories

        // Run file enumeration off the main actor to avoid blocking the UI
        let discoveredPaths: [(url: URL, relativePath: String)] = await Task.detached {
            var paths: [(url: URL, relativePath: String)] = []
            let fm = FileManager.default

            guard let enumerator = fm.enumerator(
                at: projectURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return paths
            }

            while let itemURL = enumerator.nextObject() as? URL {
                let dirName = itemURL.lastPathComponent

                // Skip excluded directories
                if skipDirs.contains(dirName) {
                    enumerator.skipDescendants()
                    continue
                }

                // Only check 3 levels deep
                let relative = itemURL.path.dropFirst(projectURL.path.count + 1)
                let depth = relative.components(separatedBy: "/").count
                if depth > 3 {
                    enumerator.skipDescendants()
                    continue
                }

                // Check for CLAUDE.md in this directory
                let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues?.isDirectory == true else { continue }

                let claudeMDURL = itemURL.appendingPathComponent("CLAUDE.md")
                if fm.fileExists(atPath: claudeMDURL.path) {
                    let relativePath = String(
                        itemURL.path.dropFirst(projectURL.path.count + 1)
                    )
                    paths.append((url: claudeMDURL, relativePath: relativePath))
                }
            }

            return paths
        }.value

        var results: [ClaudeMDFile] = []
        for entry in discoveredPaths {
            let file = await loadFile(
                url: entry.url,
                level: .subdirectory(relativePath: entry.relativePath)
            )
            results.append(file)
        }

        return results.sorted { lhs, rhs in
            lhs.displayPath < rhs.displayPath
        }
    }

    private func checkGitStatus(for url: URL) async -> Bool {
        // Determine which directory to run git in
        let isGlobal = url.path.hasPrefix(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude").path
        )
        let workingDir = isGlobal ? url.deletingLastPathComponent() : projectURL
        let filePath = url.path

        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["ls-files", "--error-unmatch", filePath]
            process.currentDirectoryURL = workingDir
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}
