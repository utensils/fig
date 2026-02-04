import AppKit
import SwiftUI

// MARK: - EffectiveConfigView

/// Read-only view showing the fully merged/resolved configuration for a project,
/// with visual indicators showing where each value comes from.
struct EffectiveConfigView: View {
    // MARK: Internal

    let mergedSettings: MergedSettings
    let envOverrides: [String: [(value: String, source: ConfigSource)]]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Toggle("View as JSON", isOn: $showJSON)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Button {
                    exportToClipboard()
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if showJSON {
                EffectiveConfigJSONView(mergedSettings: mergedSettings)
            } else {
                EffectiveConfigStructuredView(
                    mergedSettings: mergedSettings,
                    envOverrides: envOverrides
                )
            }
        }
    }

    // MARK: Private

    @State private var showJSON = false

    private func exportToClipboard() {
        let json = EffectiveConfigSerializer.toJSON(mergedSettings)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        NotificationManager.shared.showSuccess(
            "Copied to Clipboard",
            message: "Merged configuration exported as JSON"
        )
    }
}

// MARK: - EffectiveConfigStructuredView

/// Structured view showing merged settings organized by section.
struct EffectiveConfigStructuredView: View {
    let mergedSettings: MergedSettings
    let envOverrides: [String: [(value: String, source: ConfigSource)]]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SourceLegend()

                EffectivePermissionsSection(permissions: mergedSettings.permissions)
                EffectiveEnvSection(env: mergedSettings.env, overrides: envOverrides)
                EffectiveHooksSection(hooks: mergedSettings.hooks)
                EffectiveDisallowedToolsSection(tools: mergedSettings.disallowedTools)
                EffectiveAttributionSection(attribution: mergedSettings.attribution)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - EffectiveConfigJSONView

/// Raw JSON view of the merged settings.
struct EffectiveConfigJSONView: View {
    let mergedSettings: MergedSettings

    var body: some View {
        let jsonString = EffectiveConfigSerializer.toJSON(mergedSettings)
        ScrollView {
            Text(jsonString)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(.quaternary.opacity(0.3))
    }
}

// MARK: - EffectivePermissionsSection

/// Section showing merged permission rules.
struct EffectivePermissionsSection: View {
    let permissions: MergedPermissions

    var body: some View {
        GroupBox("Permissions") {
            if permissions.allow.isEmpty, permissions.deny.isEmpty {
                Text("No permission rules configured.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !permissions.allow.isEmpty {
                        Label("Allow", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)

                        ForEach(Array(permissions.allow.enumerated()), id: \.offset) { _, entry in
                            EffectiveRuleRow(
                                rule: entry.value,
                                source: entry.source,
                                icon: "checkmark.circle.fill",
                                iconColor: .green
                            )
                        }
                    }

                    if !permissions.allow.isEmpty, !permissions.deny.isEmpty {
                        Divider()
                    }

                    if !permissions.deny.isEmpty {
                        Label("Deny", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)

                        ForEach(Array(permissions.deny.enumerated()), id: \.offset) { _, entry in
                            EffectiveRuleRow(
                                rule: entry.value,
                                source: entry.source,
                                icon: "xmark.circle.fill",
                                iconColor: .red
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - EffectiveEnvSection

/// Section showing merged environment variables with override indicators.
struct EffectiveEnvSection: View {
    let env: [String: MergedValue<String>]
    let overrides: [String: [(value: String, source: ConfigSource)]]

    var body: some View {
        GroupBox("Environment Variables") {
            if env.isEmpty {
                Text("No environment variables configured.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(env.keys.sorted().enumerated()), id: \.offset) { index, key in
                        if index > 0 {
                            Divider()
                        }

                        let entry = env[key]!
                        let keyOverrides = overrides[key]

                        EffectiveEnvRow(
                            key: key,
                            effectiveValue: entry.value,
                            effectiveSource: entry.source,
                            overriddenEntries: keyOverrides?.filter { $0.source != entry.source } ?? []
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - EffectiveHooksSection

/// Section showing merged hook configurations.
struct EffectiveHooksSection: View {
    let hooks: MergedHooks

    var body: some View {
        GroupBox("Hooks") {
            if hooks.eventNames.isEmpty {
                Text("No hooks configured.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(hooks.eventNames, id: \.self) { event in
                        if let groups = hooks.groups(for: event) {
                            EffectiveHookEventView(event: event, groups: groups)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - EffectiveHookEventView

/// Displays hook groups for a single event type.
struct EffectiveHookEventView: View {
    let event: String
    let groups: [MergedValue<HookGroup>]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event)
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let matcher = group.value.matcher {
                            Text("Matcher: \(matcher)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let hookDefs = group.value.hooks {
                            ForEach(Array(hookDefs.enumerated()), id: \.offset) { _, hook in
                                HStack(spacing: 4) {
                                    Image(systemName: "terminal")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(hook.command ?? "No command")
                                        .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                    }
                    Spacer()
                    SourceBadge(source: group.source)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - EffectiveDisallowedToolsSection

/// Section showing merged disallowed tools.
struct EffectiveDisallowedToolsSection: View {
    let tools: [MergedValue<String>]

    var body: some View {
        GroupBox("Disallowed Tools") {
            if tools.isEmpty {
                Text("No tools are disallowed.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(tools.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(entry.value)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            SourceBadge(source: entry.source)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - EffectiveAttributionSection

/// Section showing merged attribution settings.
struct EffectiveAttributionSection: View {
    let attribution: MergedValue<Attribution>?

    var body: some View {
        GroupBox("Attribution") {
            if let attr = attribution {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SourceBadge(source: attr.source)
                        Spacer()
                    }
                    HStack {
                        Text("Commit Attribution")
                        Spacer()
                        Image(systemName: attr.value.commits ?? false
                            ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(attr.value.commits ?? false ? .green : .secondary)
                    }
                    HStack {
                        Text("Pull Request Attribution")
                        Spacer()
                        Image(systemName: attr.value.pullRequests ?? false
                            ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(attr.value.pullRequests ?? false ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("Using default attribution settings.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - EffectiveRuleRow

/// A row showing a single effective permission rule with its source.
struct EffectiveRuleRow: View {
    let rule: String
    let source: ConfigSource
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(rule)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            SourceBadge(source: source)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EffectiveEnvRow

/// A row displaying an effective environment variable with override information.
struct EffectiveEnvRow: View {
    // MARK: Internal

    let key: String
    let effectiveValue: String
    let effectiveSource: ConfigSource
    let overriddenEntries: [(value: String, source: ConfigSource)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EffectiveEnvValueRow(
                key: key,
                value: effectiveValue,
                source: effectiveSource,
                isSensitive: isSensitive,
                isValueVisible: $isValueVisible
            )

            if !overriddenEntries.isEmpty {
                ForEach(Array(overriddenEntries.enumerated()), id: \.offset) { _, entry in
                    EffectiveEnvOverriddenRow(
                        key: key,
                        value: entry.value,
                        source: entry.source,
                        isSensitive: isSensitive,
                        isValueVisible: isValueVisible
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Private

    @State private var isValueVisible = false

    private var isSensitive: Bool {
        let sensitivePatterns = ["token", "key", "secret", "password", "credential", "api"]
        let lowercaseKey = key.lowercased()
        return sensitivePatterns.contains { lowercaseKey.contains($0) }
    }
}

// MARK: - EffectiveEnvValueRow

/// Displays the effective (winning) value for an environment variable.
struct EffectiveEnvValueRow: View {
    let key: String
    let value: String
    let source: ConfigSource
    let isSensitive: Bool
    @Binding var isValueVisible: Bool

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(minWidth: 200, alignment: .leading)

            Text("=")
                .foregroundStyle(.secondary)

            Group {
                if isValueVisible || !isSensitive {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                } else {
                    Text(String(repeating: "\u{2022}", count: min(value.count, 20)))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSensitive {
                Button {
                    isValueVisible.toggle()
                } label: {
                    Image(systemName: isValueVisible ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            SourceBadge(source: source)
        }
    }
}

// MARK: - EffectiveEnvOverriddenRow

/// Displays an overridden environment variable value with strikethrough.
struct EffectiveEnvOverriddenRow: View {
    let key: String
    let value: String
    let source: ConfigSource
    let isSensitive: Bool
    let isValueVisible: Bool

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .strikethrough()
                .foregroundStyle(.secondary)
                .frame(minWidth: 200, alignment: .leading)

            Text("=")
                .foregroundStyle(.tertiary)
                .font(.caption)

            Group {
                if isValueVisible || !isSensitive {
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .strikethrough()
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(String(repeating: "\u{2022}", count: min(value.count, 20)))
                        .font(.system(.caption, design: .monospaced))
                        .strikethrough()
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("overridden")
                .font(.caption2)
                .foregroundStyle(.orange)
                .italic()

            SourceBadge(source: source)
        }
        .padding(.leading, 8)
    }
}

// MARK: - EffectiveConfigSerializer

/// Serializes merged settings to JSON format.
enum EffectiveConfigSerializer {
    static func toJSON(_ settings: MergedSettings) -> String {
        var result: [String: Any] = [:]

        result["permissions"] = permissionsDict(settings.permissions)
        result["env"] = envDict(settings)
        result["hooks"] = hooksDict(settings.hooks)
        result["disallowedTools"] = toolsArray(settings)
        result["attribution"] = attributionDict(settings.attribution)

        // Remove nil/empty entries
        result = result.compactMapValues { value in
            if let dict = value as? [String: Any], dict.isEmpty { return nil }
            if let arr = value as? [Any], arr.isEmpty { return nil }
            return value
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: result,
            options: [.prettyPrinted, .sortedKeys]
        ),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return jsonString
    }

    // MARK: Private

    private static func permissionsDict(_ permissions: MergedPermissions) -> [String: Any]? {
        var perms: [String: Any] = [:]
        let allow = permissions.allowPatterns
        let deny = permissions.denyPatterns
        if !allow.isEmpty { perms["allow"] = allow }
        if !deny.isEmpty { perms["deny"] = deny }
        return perms.isEmpty ? nil : perms
    }

    private static func envDict(_ settings: MergedSettings) -> [String: String]? {
        let env = settings.effectiveEnv
        return env.isEmpty ? nil : env
    }

    private static func hooksDict(_ hooks: MergedHooks) -> [String: Any]? {
        var dict: [String: [[String: Any]]] = [:]
        for event in hooks.eventNames {
            guard let groups = hooks.groups(for: event) else { continue }
            dict[event] = groups.map { group in
                var groupDict: [String: Any] = [:]
                if let matcher = group.value.matcher { groupDict["matcher"] = matcher }
                if let hookDefs = group.value.hooks {
                    groupDict["hooks"] = hookDefs.map { hook in
                        var hookDict: [String: Any] = [:]
                        if let type = hook.type { hookDict["type"] = type }
                        if let command = hook.command { hookDict["command"] = command }
                        return hookDict
                    }
                }
                return groupDict
            }
        }
        return dict.isEmpty ? nil : dict
    }

    private static func toolsArray(_ settings: MergedSettings) -> [String]? {
        let tools = settings.effectiveDisallowedTools
        return tools.isEmpty ? nil : tools
    }

    private static func attributionDict(_ attribution: MergedValue<Attribution>?) -> [String: Any]? {
        guard let attr = attribution else { return nil }
        var dict: [String: Any] = [:]
        if let commits = attr.value.commits { dict["commits"] = commits }
        if let prs = attr.value.pullRequests { dict["pullRequests"] = prs }
        return dict.isEmpty ? nil : dict
    }
}

#Preview("Effective Config") {
    EffectiveConfigView(
        mergedSettings: MergedSettings(
            permissions: MergedPermissions(
                allow: [
                    MergedValue(value: "Bash(npm run *)", source: .global),
                    MergedValue(value: "Read(src/**)", source: .projectShared)
                ],
                deny: [
                    MergedValue(value: "Read(.env)", source: .projectLocal)
                ]
            ),
            env: [
                "CLAUDE_CODE_MAX_OUTPUT_TOKENS": MergedValue(value: "16384", source: .projectLocal),
                "ANTHROPIC_MODEL": MergedValue(value: "claude-sonnet-4-20250514", source: .global)
            ],
            disallowedTools: [
                MergedValue(value: "WebFetch", source: .projectShared)
            ],
            attribution: MergedValue(
                value: Attribution(commits: true, pullRequests: false),
                source: .projectShared
            )
        ),
        envOverrides: [
            "CLAUDE_CODE_MAX_OUTPUT_TOKENS": [
                ("8192", .global),
                ("16384", .projectLocal)
            ]
        ]
    )
    .padding()
    .frame(width: 700, height: 600)
}
