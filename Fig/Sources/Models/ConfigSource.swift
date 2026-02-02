import Foundation

/// Represents the source of a configuration value in the merge hierarchy.
///
/// Values are listed in order of precedence (lowest to highest):
/// - `global`: User's global settings (`~/.claude/settings.json`)
/// - `projectShared`: Project-level shared settings (`.claude/settings.json`)
/// - `projectLocal`: Project-level local settings (`.claude/settings.local.json`)
public enum ConfigSource: String, Sendable, Equatable, Hashable, CaseIterable, Comparable {
    /// User's global settings (~/.claude/settings.json).
    case global

    /// Project-level shared settings (.claude/settings.json).
    case projectShared

    /// Project-level local settings (.claude/settings.local.json, gitignored).
    case projectLocal

    // MARK: Public

    /// Display name for the configuration source.
    public var displayName: String {
        switch self {
        case .global:
            "Global"
        case .projectShared:
            "Project"
        case .projectLocal:
            "Local"
        }
    }

    /// Short label for the configuration source.
    public var label: String {
        switch self {
        case .global:
            "Global"
        case .projectShared:
            "Shared"
        case .projectLocal:
            "Local"
        }
    }

    /// SF Symbol icon name for the configuration source.
    public var icon: String {
        switch self {
        case .global:
            "globe"
        case .projectShared:
            "person.2"
        case .projectLocal:
            "person"
        }
    }

    /// File name associated with this source.
    public var fileName: String {
        switch self {
        case .global:
            "~/.claude/settings.json"
        case .projectShared:
            ".claude/settings.json"
        case .projectLocal:
            ".claude/settings.local.json"
        }
    }

    /// Precedence level (higher wins in merges).
    public var precedence: Int {
        switch self {
        case .global:
            0
        case .projectShared:
            1
        case .projectLocal:
            2
        }
    }

    public static func < (lhs: ConfigSource, rhs: ConfigSource) -> Bool {
        lhs.precedence < rhs.precedence
    }
}
