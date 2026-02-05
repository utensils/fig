import AppKit
import SwiftUI

// MARK: - SourceBadge

/// A small badge indicating the source of a configuration value.
struct SourceBadge: View {
    // MARK: Internal

    let source: ConfigSource

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: self.source.icon)
                .font(.caption2)
            Text(self.source.label)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(self.backgroundColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
        .foregroundStyle(self.backgroundColor)
        .accessibilityLabel("Source: \(self.source.label)")
    }

    // MARK: Private

    private var backgroundColor: Color {
        switch self.source {
        case .global:
            .blue
        case .projectShared:
            .purple
        case .projectLocal:
            .orange
        }
    }
}

// MARK: - PermissionsTabView

/// Tab view displaying permission rules.
struct PermissionsTabView: View {
    // MARK: Internal

    var permissions: Permissions?
    var allPermissions: [(rule: String, type: PermissionType, source: ConfigSource)]?
    var source: ConfigSource?
    var emptyMessage = "No permission rules configured."

    /// Callback when a rule should be promoted to global settings.
    var onPromoteToGlobal: ((String, PermissionType) -> Void)?

    /// Callback when a rule should be copied to another scope.
    var onCopyToScope: ((String, PermissionType, ConfigSource) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Source legend for project views
                if self.allPermissions != nil {
                    SourceLegend()
                }

                // Allow rules
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Allow Rules", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        let allowRules = self.allowPermissions
                        if allowRules.isEmpty {
                            Text("No allow rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(Array(allowRules.enumerated()), id: \.offset) { _, item in
                                PermissionRuleRow(
                                    rule: item.rule,
                                    type: .allow,
                                    source: item.source,
                                    isOverride: self.isRuleOverridingGlobal(
                                        rule: item.rule,
                                        type: .allow,
                                        source: item.source
                                    ),
                                    onPromoteToGlobal: self.onPromoteToGlobal,
                                    onCopyToScope: self.onCopyToScope
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Deny rules
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Deny Rules", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)

                        let denyRules = self.denyPermissions
                        if denyRules.isEmpty {
                            Text("No deny rules configured.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(Array(denyRules.enumerated()), id: \.offset) { _, item in
                                PermissionRuleRow(
                                    rule: item.rule,
                                    type: .deny,
                                    source: item.source,
                                    isOverride: self.isRuleOverridingGlobal(
                                        rule: item.rule,
                                        type: .deny,
                                        source: item.source
                                    ),
                                    onPromoteToGlobal: self.onPromoteToGlobal,
                                    onCopyToScope: self.onCopyToScope
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private var allowPermissions: [(rule: String, source: ConfigSource)] {
        if let allPermissions {
            return allPermissions.filter { $0.type == .allow }.map { ($0.rule, $0.source) }
        }
        if let permissions, let source {
            return (permissions.allow ?? []).map { ($0, source) }
        }
        return []
    }

    private var denyPermissions: [(rule: String, source: ConfigSource)] {
        if let allPermissions {
            return allPermissions.filter { $0.type == .deny }.map { ($0.rule, $0.source) }
        }
        if let permissions, let source {
            return (permissions.deny ?? []).map { ($0, source) }
        }
        return []
    }

    /// Checks if a project-level rule also exists at the global level.
    private func isRuleOverridingGlobal(rule: String, type: PermissionType, source: ConfigSource) -> Bool {
        guard source != .global, let allPermissions else {
            return false
        }
        return allPermissions.contains { $0.rule == rule && $0.type == type && $0.source == .global }
    }
}

// MARK: - PermissionRuleRow

/// A row displaying a single permission rule.
struct PermissionRuleRow: View {
    let rule: String
    let type: PermissionType
    let source: ConfigSource
    var isOverride = false
    var onPromoteToGlobal: ((String, PermissionType) -> Void)?
    var onCopyToScope: ((String, PermissionType, ConfigSource) -> Void)?

    var body: some View {
        HStack {
            Image(systemName: self.type.icon)
                .foregroundStyle(self.type == .allow ? .green : .red)
                .frame(width: 20)

            Text(self.rule)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            if self.isOverride {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                    .help("This rule also exists in global settings")
            }

            Spacer()

            SourceBadge(source: self.source)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(self.type == .allow ? "Allow" : "Deny") rule: \(self.rule), source: \(self.source.label)"
        )
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.rule, forType: .string)
            } label: {
                Label("Copy Rule", systemImage: "doc.on.doc")
            }

            if self.source != .global, self.onPromoteToGlobal != nil {
                Divider()

                Button {
                    self.onPromoteToGlobal?(self.rule, self.type)
                } label: {
                    Label("Promote to Global", systemImage: "arrow.up.to.line")
                }
            }

            if self.source == .projectShared || self.source == .projectLocal {
                let otherScope: ConfigSource = self.source == .projectShared ? .projectLocal : .projectShared
                if self.onCopyToScope != nil {
                    Button {
                        self.onCopyToScope?(self.rule, self.type, otherScope)
                    } label: {
                        Label("Copy to \(otherScope.label)", systemImage: "arrow.left.arrow.right")
                    }
                }
            }
        }
    }
}

// MARK: - EnvironmentTabView

/// Tab view displaying environment variables.
struct EnvironmentTabView: View {
    let envVars: [(key: String, value: String, source: ConfigSource)]
    var emptyMessage = "No environment variables configured."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !self.envVars.isEmpty {
                    SourceLegend()
                }

                if self.envVars.isEmpty {
                    ContentUnavailableView(
                        "No Environment Variables",
                        systemImage: "list.bullet.rectangle",
                        description: Text(self.emptyMessage)
                    )
                } else {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(self.envVars.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    Divider()
                                }
                                EnvironmentVariableRow(
                                    key: item.key,
                                    value: item.value,
                                    source: item.source
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - EnvironmentVariableRow

/// A row displaying a single environment variable.
struct EnvironmentVariableRow: View {
    // MARK: Internal

    let key: String
    let value: String
    let source: ConfigSource

    var body: some View {
        HStack(alignment: .top) {
            Text(self.key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(minWidth: 200, alignment: .leading)

            Text("=")
                .foregroundStyle(.secondary)

            Group {
                if self.isValueVisible || !self.isSensitive {
                    Text(self.value)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                } else {
                    Text(String(repeating: "\u{2022}", count: min(self.value.count, 20)))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if self.isSensitive {
                Button {
                    self.isValueVisible.toggle()
                } label: {
                    Image(systemName: self.isValueVisible ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(self.isValueVisible ? "Hide value" : "Show value")
                .accessibilityHint("Toggles visibility of sensitive value for \(self.key)")
            }

            SourceBadge(source: self.source)
        }
        .padding(.vertical, 8)
    }

    // MARK: Private

    @State private var isValueVisible = false

    private var isSensitive: Bool {
        let sensitivePatterns = ["token", "key", "secret", "password", "credential", "api"]
        let lowercaseKey = self.key.lowercased()
        return sensitivePatterns.contains { lowercaseKey.contains($0) }
    }
}

// MARK: - MCPServersTabView

/// Tab view displaying MCP server configurations.
struct MCPServersTabView: View {
    let servers: [(name: String, server: MCPServer, source: ConfigSource)]
    var emptyMessage = "No MCP servers configured."
    var projectPath: URL?
    var onAdd: (() -> Void)?
    var onEdit: ((String, MCPServer, ConfigSource) -> Void)?
    var onDelete: ((String, ConfigSource) -> Void)?
    var onCopy: ((String, MCPServer) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            if self.onAdd != nil {
                HStack {
                    Spacer()
                    Button {
                        self.onAdd?()
                    } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !self.servers.isEmpty {
                        SourceLegend()
                    }

                    if self.servers.isEmpty {
                        ContentUnavailableView(
                            "No MCP Servers",
                            systemImage: "server.rack",
                            description: Text(self.emptyMessage)
                        )
                    } else {
                        ForEach(Array(self.servers.enumerated()), id: \.offset) { _, item in
                            MCPServerCard(
                                name: item.name,
                                server: item.server,
                                source: item.source,
                                onEdit: self.onEdit != nil ? {
                                    self.onEdit?(item.name, item.server, item.source)
                                } : nil,
                                onDelete: self.onDelete != nil ? {
                                    self.onDelete?(item.name, item.source)
                                } : nil,
                                onCopy: self.onCopy != nil ? {
                                    self.onCopy?(item.name, item.server)
                                } : nil
                            )
                        }
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - MCPServerCard

/// A card displaying MCP server details.
struct MCPServerCard: View {
    // MARK: Internal

    let name: String
    let server: MCPServer
    let source: ConfigSource
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onCopy: (() -> Void)?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: self.server.isHTTP ? "globe" : "terminal")
                        .foregroundStyle(self.server.isHTTP ? .blue : .green)

                    Text(self.name)
                        .font(.headline)

                    Text(self.server.isHTTP ? "HTTP" : "Stdio")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    // Action buttons
                    HStack(spacing: 4) {
                        // Health check button
                        MCPHealthCheckButton(serverName: self.name, server: self.server)

                        // Copy to clipboard
                        Button {
                            self.copyToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Copy as JSON")
                        .accessibilityLabel("Copy \(self.name) as JSON")

                        // Copy to project
                        if self.onCopy != nil {
                            Button {
                                self.onCopy?()
                            } label: {
                                Image(systemName: "arrow.right.doc.on.clipboard")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Copy to...")
                            .accessibilityLabel("Copy \(self.name) to another project")
                        }

                        if self.onEdit != nil {
                            Button {
                                self.onEdit?()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Edit server")
                            .accessibilityLabel("Edit \(self.name)")
                        }

                        if self.onDelete != nil {
                            Button {
                                self.onDelete?()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete server")
                            .accessibilityLabel("Delete \(self.name)")
                        }
                    }

                    SourceBadge(source: self.source)

                    Button {
                        withAnimation {
                            self.isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(self
                        .isExpanded ? "Collapse \(self.name) details" : "Expand \(self.name) details")
                }

                // Summary line
                if self.server.isHTTP {
                    if let url = server.url {
                        Text(url)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let command = server.command {
                    HStack(spacing: 4) {
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                        if let args = server.args, !args.isEmpty {
                            Text(args.joined(separator: " "))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Expanded details
                if self.isExpanded {
                    Divider()

                    if self.server.isHTTP {
                        if let headers = server.headers, !headers.isEmpty {
                            Text("Headers:")
                                .font(.caption)
                                .fontWeight(.medium)
                            ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                    Text(":")
                                        .foregroundStyle(.secondary)
                                    Text(self.maskSensitiveValue(key: key, value: headers[key] ?? ""))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        if let env = server.env, !env.isEmpty {
                            Text("Environment:")
                                .font(.caption)
                                .fontWeight(.medium)
                            ForEach(Array(env.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(.caption, design: .monospaced))
                                    Text("=")
                                        .foregroundStyle(.secondary)
                                    Text(self.maskSensitiveValue(key: key, value: env[key] ?? ""))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button {
                self.copyToClipboard()
            } label: {
                Label("Copy as JSON", systemImage: "doc.on.doc")
            }

            if self.onCopy != nil {
                Button {
                    self.onCopy?()
                } label: {
                    Label("Copy to...", systemImage: "arrow.right.doc.on.clipboard")
                }
            }

            Divider()

            if self.onEdit != nil {
                Button {
                    self.onEdit?()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if self.onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    self.onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: Private

    @State private var isExpanded = false

    private func maskSensitiveValue(key: String, value: String) -> String {
        let sensitivePatterns = ["token", "key", "secret", "password", "credential", "api", "authorization"]
        let lowercaseKey = key.lowercased()
        if sensitivePatterns.contains(where: { lowercaseKey.contains($0) }) {
            return String(repeating: "\u{2022}", count: min(value.count, 20))
        }
        return value
    }

    private func copyToClipboard() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode([name: server]),
           let jsonString = String(data: data, encoding: .utf8)
        {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
            NotificationManager.shared.showSuccess(
                "Copied to clipboard",
                message: "Server '\(self.name)' copied as JSON"
            )
        }
    }
}

// MARK: - HooksTabView

/// Tab view displaying hook configurations.
struct HooksTabView: View {
    // MARK: Internal

    let globalHooks: [String: [HookGroup]]?
    let projectHooks: [String: [HookGroup]]?
    let localHooks: [String: [HookGroup]]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SourceLegend()

                if self.allHooksEmpty {
                    ContentUnavailableView(
                        "No Hooks Configured",
                        systemImage: "arrow.triangle.branch",
                        description: Text(
                            "Hooks allow you to run custom commands before or after Claude Code operations."
                        )
                    )
                } else {
                    // List all hook events
                    ForEach(self.allHookEvents, id: \.self) { event in
                        HookEventSection(
                            event: event,
                            globalGroups: self.globalHooks?[event],
                            projectGroups: self.projectHooks?[event],
                            localGroups: self.localHooks?[event]
                        )
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private var allHooksEmpty: Bool {
        (self.globalHooks?.isEmpty ?? true) &&
            (self.projectHooks?.isEmpty ?? true) &&
            (self.localHooks?.isEmpty ?? true)
    }

    private var allHookEvents: [String] {
        var events = Set<String>()
        if let global = globalHooks {
            events.formUnion(global.keys)
        }
        if let project = projectHooks {
            events.formUnion(project.keys)
        }
        if let local = localHooks {
            events.formUnion(local.keys)
        }
        return events.sorted()
    }
}

// MARK: - HookEventSection

/// Section showing hooks for a specific event.
struct HookEventSection: View {
    let event: String
    let globalGroups: [HookGroup]?
    let projectGroups: [HookGroup]?
    let localGroups: [HookGroup]?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(self.event)
                    .font(.headline)

                // Global hooks
                if let groups = globalGroups {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        HookGroupRow(group: group, source: .global)
                    }
                }

                // Project hooks
                if let groups = projectGroups {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        HookGroupRow(group: group, source: .projectShared)
                    }
                }

                // Local hooks
                if let groups = localGroups {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        HookGroupRow(group: group, source: .projectLocal)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - HookGroupRow

/// A row displaying a hook group.
struct HookGroupRow: View {
    let group: HookGroup
    let source: ConfigSource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let matcher = group.matcher {
                    Text("Matcher: \(matcher)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SourceBadge(source: self.source)
            }

            if let hooks = group.hooks {
                ForEach(Array(hooks.enumerated()), id: \.offset) { _, hook in
                    HStack {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hook.command ?? "No command")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - SourceLegend

/// Legend explaining source badge colors.
struct SourceLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("Source:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(ConfigSource.allCases, id: \.rawValue) { source in
                SourceBadge(source: source)
            }
        }
        .padding(.bottom, 8)
    }
}

#Preview("Permissions Tab") {
    PermissionsTabView(
        allPermissions: [
            ("Bash(npm run *)", .allow, .global),
            ("Read(src/**)", .allow, .projectShared),
            ("Read(.env)", .deny, .projectLocal),
        ]
    )
    .padding()
    .frame(width: 600, height: 400)
}

#Preview("Environment Tab") {
    EnvironmentTabView(
        envVars: [
            ("CLAUDE_CODE_MAX_OUTPUT_TOKENS", "16384", .global),
            ("API_KEY", "sk-1234567890", .projectLocal),
        ]
    )
    .padding()
    .frame(width: 600, height: 400)
}

#Preview("MCP Servers Tab") {
    MCPServersTabView(
        servers: [
            ("github", .stdio(command: "npx", args: ["-y", "@mcp/server-github"]), .projectShared),
            ("api", .http(url: "https://mcp.example.com"), .global),
        ]
    )
    .padding()
    .frame(width: 600, height: 400)
}
