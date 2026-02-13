import Foundation

// MARK: - ProjectGroup

/// A group of projects sharing the same parent directory.
///
/// Used to visually organize projects in the sidebar when grouping
/// by parent directory is enabled. This reduces noise from git worktrees
/// and similar directory structures where many projects share a common parent.
struct ProjectGroup: Identifiable, Sendable {
    /// The full path to the parent directory.
    let parentPath: String

    /// Display-friendly name (abbreviated with ~).
    let displayName: String

    /// Projects in this group, sorted by name.
    let projects: [ProjectEntry]

    var id: String { self.parentPath }
}
