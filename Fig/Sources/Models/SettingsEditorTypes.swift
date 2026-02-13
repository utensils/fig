import Foundation
import SwiftUI

// MARK: - EditablePermissionRule

/// A permission rule with editing metadata.
struct EditablePermissionRule: Identifiable, Equatable, Hashable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), rule: String, type: PermissionType) {
        self.id = id
        self.rule = rule
        self.type = type
    }

    // MARK: Internal

    let id: UUID
    var rule: String
    var type: PermissionType
}

// MARK: - EditableEnvironmentVariable

/// An environment variable with editing metadata.
struct EditableEnvironmentVariable: Identifiable, Equatable, Hashable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }

    // MARK: Internal

    let id: UUID
    var key: String
    var value: String
}

// MARK: - KnownEnvironmentVariable

/// Known Claude Code environment variables with descriptions.
struct KnownEnvironmentVariable: Identifiable {
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
        ),
    ]

    let id: String
    let name: String
    let description: String
    let defaultValue: String?

    static func description(for key: String) -> String? {
        self.allVariables.first { $0.name == key }?.description
    }
}

// MARK: - PermissionPreset

/// Quick-add presets for common permission patterns.
struct PermissionPreset: Identifiable {
    static let allPresets: [PermissionPreset] = [
        PermissionPreset(
            id: "protect-env",
            name: "Protect .env files",
            description: "Prevent reading environment files",
            rules: [
                ("Read(.env)", .deny),
                ("Read(.env.*)", .deny),
            ]
        ),
        PermissionPreset(
            id: "allow-npm",
            name: "Allow npm scripts",
            description: "Allow running npm scripts",
            rules: [
                ("Bash(npm run *)", .allow),
            ]
        ),
        PermissionPreset(
            id: "allow-git",
            name: "Allow git operations",
            description: "Allow running git commands",
            rules: [
                ("Bash(git *)", .allow),
            ]
        ),
        PermissionPreset(
            id: "read-only",
            name: "Read-only mode",
            description: "Deny all write and edit operations",
            rules: [
                ("Write", .deny),
                ("Edit", .deny),
            ]
        ),
        PermissionPreset(
            id: "allow-read-src",
            name: "Allow reading source",
            description: "Allow reading all files in src directory",
            rules: [
                ("Read(src/**)", .allow),
            ]
        ),
        PermissionPreset(
            id: "deny-curl",
            name: "Block curl commands",
            description: "Prevent curl network requests",
            rules: [
                ("Bash(curl *)", .deny),
            ]
        ),
    ]

    let id: String
    let name: String
    let description: String
    let rules: [(rule: String, type: PermissionType)]
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

    // MARK: Internal

    var id: String {
        rawValue
    }

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
    case global
    case projectShared
    case projectLocal

    // MARK: Internal

    /// Targets available when editing project settings.
    static var projectTargets: [EditingTarget] {
        [.projectShared, .projectLocal]
    }

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .global:
            "Global (settings.json)"
        case .projectShared:
            "Shared (settings.json)"
        case .projectLocal:
            "Local (settings.local.json)"
        }
    }

    var description: String {
        switch self {
        case .global:
            "Applies to all projects"
        case .projectShared:
            "Committed to git, shared with team"
        case .projectLocal:
            "Git-ignored, local overrides"
        }
    }

    var source: ConfigSource {
        switch self {
        case .global:
            .global
        case .projectShared:
            .projectShared
        case .projectLocal:
            .projectLocal
        }
    }
}

// MARK: - EditableHookDefinition

/// A hook definition with editing metadata.
struct EditableHookDefinition: Identifiable, Equatable, Hashable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), type: String = "command", command: String = "") {
        self.id = id
        self.type = type
        self.command = command
        self.additionalProperties = nil
    }

    init(from definition: HookDefinition) {
        self.id = UUID()
        self.type = definition.type ?? "command"
        self.command = definition.command ?? ""
        self.additionalProperties = definition.additionalProperties
    }

    // MARK: Internal

    let id: UUID
    var type: String
    var command: String
    var additionalProperties: [String: AnyCodable]?

    func toHookDefinition() -> HookDefinition {
        HookDefinition(
            type: self.type,
            command: self.command.isEmpty ? nil : self.command,
            additionalProperties: self.additionalProperties
        )
    }
}

// MARK: - EditableHookGroup

/// A hook group with editing metadata.
struct EditableHookGroup: Identifiable, Equatable, Hashable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), matcher: String = "", hooks: [EditableHookDefinition] = []) {
        self.id = id
        self.matcher = matcher
        self.hooks = hooks
        self.additionalProperties = nil
    }

    init(from group: HookGroup) {
        self.id = UUID()
        self.matcher = group.matcher ?? ""
        self.hooks = (group.hooks ?? []).map { EditableHookDefinition(from: $0) }
        self.additionalProperties = group.additionalProperties
    }

    // MARK: Internal

    let id: UUID
    var matcher: String
    var hooks: [EditableHookDefinition]
    var additionalProperties: [String: AnyCodable]?

    func toHookGroup() -> HookGroup {
        HookGroup(
            matcher: self.matcher.isEmpty ? nil : self.matcher,
            hooks: self.hooks.isEmpty ? nil : self.hooks.map { $0.toHookDefinition() },
            additionalProperties: self.additionalProperties
        )
    }
}

// MARK: - HookEvent

/// Hook lifecycle event types.
enum HookEvent: String, CaseIterable, Identifiable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case notification = "Notification"
    case stop = "Stop"

    // MARK: Internal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .preToolUse: "Pre Tool Use"
        case .postToolUse: "Post Tool Use"
        case .notification: "Notification"
        case .stop: "Stop"
        }
    }

    var description: String {
        switch self {
        case .preToolUse: "Runs before a tool is executed"
        case .postToolUse: "Runs after a tool finishes executing"
        case .notification: "Runs when Claude sends notifications"
        case .stop: "Runs when Claude finishes responding"
        }
    }

    var icon: String {
        switch self {
        case .preToolUse: "arrow.right.circle"
        case .postToolUse: "arrow.left.circle"
        case .notification: "bell"
        case .stop: "stop.circle"
        }
    }

    var matcherPlaceholder: String {
        switch self {
        case .preToolUse: "Bash(*), Read(src/**), Write, etc."
        case .postToolUse: "Bash(*), Edit(*.py), etc."
        case .notification: "Optional pattern..."
        case .stop: "Optional pattern..."
        }
    }

    var supportsMatcher: Bool {
        switch self {
        case .preToolUse,
             .postToolUse: true
        case .notification,
             .stop: false
        }
    }

    var color: Color {
        switch self {
        case .preToolUse: .blue
        case .postToolUse: .green
        case .notification: .orange
        case .stop: .red
        }
    }
}

// MARK: - HookVariable

/// Describes an environment variable available in hook scripts.
struct HookVariable: Identifiable, Sendable {
    let name: String
    let description: String
    let events: [HookEvent]

    var id: String { name }
}

// MARK: - HookVariable + Catalog

extension HookVariable {
    /// All available hook variables.
    static let all: [HookVariable] = [
        HookVariable(
            name: "$CLAUDE_TOOL_NAME",
            description: "Name of the tool being used",
            events: [.preToolUse, .postToolUse]
        ),
        HookVariable(
            name: "$CLAUDE_TOOL_INPUT",
            description: "JSON input to the tool",
            events: [.preToolUse, .postToolUse]
        ),
        HookVariable(
            name: "$CLAUDE_FILE_PATH",
            description: "File path affected (if applicable)",
            events: [.preToolUse, .postToolUse]
        ),
        HookVariable(
            name: "$CLAUDE_TOOL_OUTPUT",
            description: "Output from the tool",
            events: [.postToolUse]
        ),
        HookVariable(
            name: "$CLAUDE_NOTIFICATION",
            description: "Notification message",
            events: [.notification]
        ),
    ]
}

// MARK: - HookTemplate

/// Quick-add templates for common hook configurations.
struct HookTemplate: Identifiable {
    static let allTemplates: [HookTemplate] = [
        HookTemplate(
            id: "format-python",
            name: "Format Python on save",
            description: "Run black formatter after writing Python files",
            event: .postToolUse,
            matcher: "Write(*.py)",
            commands: ["black $CLAUDE_FILE_PATH"]
        ),
        HookTemplate(
            id: "lint-after-edit",
            name: "Run linter after edit",
            description: "Run ESLint after editing TypeScript files",
            event: .postToolUse,
            matcher: "Edit(*.ts)",
            commands: ["npx eslint --fix $CLAUDE_FILE_PATH"]
        ),
        HookTemplate(
            id: "notify-completion",
            name: "Notify on completion",
            description: "Send a system notification when Claude stops",
            event: .stop,
            matcher: nil,
            commands: [
                "osascript -e 'display notification \"Claude Code finished\" with title \"Fig\"'",
            ]
        ),
        HookTemplate(
            id: "pre-bash-guard",
            name: "Guard dangerous commands",
            description: "Log all bash commands before execution",
            event: .preToolUse,
            matcher: "Bash(*)",
            commands: ["echo \"Running: $CLAUDE_TOOL_INPUT\" >> ~/.claude/hook.log"]
        ),
        HookTemplate(
            id: "post-write-test",
            name: "Run tests after write",
            description: "Run tests after writing test files",
            event: .postToolUse,
            matcher: "Write(*test*)",
            commands: ["npm test"]
        ),
        HookTemplate(
            id: "format-swift",
            name: "Format Swift on save",
            description: "Run swift-format after writing Swift files",
            event: .postToolUse,
            matcher: "Write(*.swift)",
            commands: ["swift-format format -i $CLAUDE_FILE_PATH"]
        ),
    ]

    let id: String
    let name: String
    let description: String
    let event: HookEvent
    let matcher: String?
    let commands: [String]
}

// MARK: - ConflictResolution

/// Options for resolving external file change conflicts.
enum ConflictResolution {
    case keepLocal
    case useExternal
}
