import Foundation

/// Represents a project discovered from the legacy config or filesystem scan.
///
/// Contains metadata about the project's location, existence status,
/// available configuration files, and last modification time.
///
/// Example:
/// ```swift
/// let project = DiscoveredProject(
///     path: "/Users/sean/code/relay",
///     displayName: "relay",
///     exists: true,
///     hasSettings: true,
///     hasLocalSettings: false,
///     hasMCPConfig: true,
///     lastModified: Date()
/// )
/// ```
public struct DiscoveredProject: Sendable, Identifiable, Equatable, Hashable {
    // MARK: Lifecycle

    public init(
        path: String,
        displayName: String,
        exists: Bool,
        hasSettings: Bool,
        hasLocalSettings: Bool,
        hasMCPConfig: Bool,
        lastModified: Date?
    ) {
        self.path = path
        self.displayName = displayName
        self.exists = exists
        self.hasSettings = hasSettings
        self.hasLocalSettings = hasLocalSettings
        self.hasMCPConfig = hasMCPConfig
        self.lastModified = lastModified
    }

    // MARK: Public

    /// The absolute path to the project directory.
    public let path: String

    /// Human-readable name derived from the directory name.
    public let displayName: String

    /// Whether the project directory still exists on disk.
    public let exists: Bool

    /// Whether the project has a `.claude/settings.json` file.
    public let hasSettings: Bool

    /// Whether the project has a `.claude/settings.local.json` file.
    public let hasLocalSettings: Bool

    /// Whether the project has a `.mcp.json` file.
    public let hasMCPConfig: Bool

    /// Last modification time of the project directory or config files.
    public let lastModified: Date?

    /// Unique identifier based on the path.
    public var id: String {
        self.path
    }

    /// URL representation of the project path.
    public var url: URL {
        URL(fileURLWithPath: self.path)
    }

    /// Returns true if the project has any configuration files.
    public var hasAnyConfig: Bool {
        self.hasSettings || self.hasLocalSettings || self.hasMCPConfig
    }
}
