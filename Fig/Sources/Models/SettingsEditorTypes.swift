import Foundation

// MARK: - EditablePermissionRule

/// A permission rule with editing metadata.
struct EditablePermissionRule: Identifiable, Equatable, Hashable {
    let id: UUID
    var rule: String
    var type: PermissionType

    init(id: UUID = UUID(), rule: String, type: PermissionType) {
        self.id = id
        self.rule = rule
        self.type = type
    }
}

// MARK: - EditableEnvironmentVariable

/// An environment variable with editing metadata.
struct EditableEnvironmentVariable: Identifiable, Equatable, Hashable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

// MARK: - KnownEnvironmentVariable

/// Known Claude Code environment variables with descriptions.
struct KnownEnvironmentVariable: Identifiable {
    let id: String
    let name: String
    let description: String
    let defaultValue: String?

    static let allVariables: [KnownEnvironmentVariable] = [
        KnownEnvironmentVariable(
            id: "CLAUDE_CODE_MAX_OUTPUT_TOKENS",
            name: "CLAUDE_CODE_MAX_OUTPUT_TOKENS",
            description: "Maximum tokens in Claude's response",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "BASH_DEFAULT_TIMEOUT_MS",
            name: "BASH_DEFAULT_TIMEOUT_MS",
            description: "Default timeout for bash commands in milliseconds",
            defaultValue: "120000"
        ),
        KnownEnvironmentVariable(
            id: "CLAUDE_CODE_ENABLE_TELEMETRY",
            name: "CLAUDE_CODE_ENABLE_TELEMETRY",
            description: "Enable/disable telemetry (0 or 1)",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "OTEL_METRICS_EXPORTER",
            name: "OTEL_METRICS_EXPORTER",
            description: "OpenTelemetry metrics exporter configuration",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "DISABLE_TELEMETRY",
            name: "DISABLE_TELEMETRY",
            description: "Disable all telemetry (0 or 1)",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
            name: "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
            description: "Reduce network calls by disabling non-essential traffic",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "ANTHROPIC_MODEL",
            name: "ANTHROPIC_MODEL",
            description: "Override the default model used by Claude Code",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "ANTHROPIC_DEFAULT_SONNET_MODEL",
            name: "ANTHROPIC_DEFAULT_SONNET_MODEL",
            description: "Default Sonnet model to use",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "ANTHROPIC_DEFAULT_OPUS_MODEL",
            name: "ANTHROPIC_DEFAULT_OPUS_MODEL",
            description: "Default Opus model to use",
            defaultValue: nil
        ),
        KnownEnvironmentVariable(
            id: "ANTHROPIC_DEFAULT_HAIKU_MODEL",
            name: "ANTHROPIC_DEFAULT_HAIKU_MODEL",
            description: "Default Haiku model to use",
            defaultValue: nil
        )
    ]

    static func description(for key: String) -> String? {
        allVariables.first { $0.name == key }?.description
    }
}

// MARK: - PermissionPreset

/// Quick-add presets for common permission patterns.
struct PermissionPreset: Identifiable {
    let id: String
    let name: String
    let description: String
    let rules: [(rule: String, type: PermissionType)]

    static let allPresets: [PermissionPreset] = [
        PermissionPreset(
            id: "protect-env",
            name: "Protect .env files",
            description: "Prevent reading environment files",
            rules: [
                ("Read(.env)", .deny),
                ("Read(.env.*)", .deny)
            ]
        ),
        PermissionPreset(
            id: "allow-npm",
            name: "Allow npm scripts",
            description: "Allow running npm scripts",
            rules: [
                ("Bash(npm run *)", .allow)
            ]
        ),
        PermissionPreset(
            id: "allow-git",
            name: "Allow git operations",
            description: "Allow running git commands",
            rules: [
                ("Bash(git *)", .allow)
            ]
        ),
        PermissionPreset(
            id: "read-only",
            name: "Read-only mode",
            description: "Deny all write and edit operations",
            rules: [
                ("Write", .deny),
                ("Edit", .deny)
            ]
        ),
        PermissionPreset(
            id: "allow-read-src",
            name: "Allow reading source",
            description: "Allow reading all files in src directory",
            rules: [
                ("Read(src/**)", .allow)
            ]
        ),
        PermissionPreset(
            id: "deny-curl",
            name: "Block curl commands",
            description: "Prevent curl network requests",
            rules: [
                ("Bash(curl *)", .deny)
            ]
        )
    ]
}

// MARK: - ToolType

/// Known tool types for permission rules.
enum ToolType: String, CaseIterable, Identifiable {
    case bash = "Bash"
    case read = "Read"
    case write = "Write"
    case edit = "Edit"
    case grep = "Grep"
    case glob = "Glob"
    case webFetch = "WebFetch"
    case notebook = "Notebook"
    case custom = "Custom"

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .bash:
            "npm run *, git *, etc."
        case .read:
            "src/**, .env, config/*.json"
        case .write:
            "*.log, temp/*, dist/**"
        case .edit:
            "src/**/*.ts, package.json"
        case .grep:
            "*.ts, src/**"
        case .glob:
            "**/*.test.ts"
        case .webFetch:
            "https://api.example.com/*"
        case .notebook:
            "*.ipynb"
        case .custom:
            "Enter tool name..."
        }
    }

    var supportsPattern: Bool {
        true // All tools support patterns
    }
}

// MARK: - EditingTarget

/// Target file for saving edited settings.
enum EditingTarget: String, CaseIterable, Identifiable {
    case projectShared
    case projectLocal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .projectShared:
            "Shared (settings.json)"
        case .projectLocal:
            "Local (settings.local.json)"
        }
    }

    var description: String {
        switch self {
        case .projectShared:
            "Committed to git, shared with team"
        case .projectLocal:
            "Git-ignored, local overrides"
        }
    }

    var source: ConfigSource {
        switch self {
        case .projectShared:
            .projectShared
        case .projectLocal:
            .projectLocal
        }
    }
}

// MARK: - ConflictResolution

/// Options for resolving external file change conflicts.
enum ConflictResolution {
    case keepLocal
    case useExternal
    case viewDiff
}
