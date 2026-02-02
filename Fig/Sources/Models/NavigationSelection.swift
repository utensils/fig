import Foundation

/// Represents the current selection in the sidebar navigation.
enum NavigationSelection: Hashable, Sendable {
    /// Global settings view (~/.claude/settings.json).
    case globalSettings

    /// A specific project selected by its path.
    case project(String)

    // MARK: Internal

    /// Returns the project path if this is a project selection.
    var projectPath: String? {
        if case let .project(path) = self {
            return path
        }
        return nil
    }

    /// Whether this selection is for global settings.
    var isGlobalSettings: Bool {
        if case .globalSettings = self {
            return true
        }
        return false
    }
}
