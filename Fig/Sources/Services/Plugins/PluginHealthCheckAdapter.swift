import Foundation
import lua4swift
import OSLog

// MARK: - PluginHealthCheckAdapter

/// Bridges plugin-registered health checks with the existing Swift health check system.
///
/// This adapter converts `HealthCheckContext` to Lua tables, executes registered
/// Lua health check functions, and converts the results back to Swift `Finding` types.
enum PluginHealthCheckAdapter {
    // MARK: Internal

    /// Executes a single plugin health check using the provided sandbox.
    ///
    /// - Parameters:
    ///   - checkId: Identifier for this health check
    ///   - pluginId: The plugin that registered this check
    ///   - function: The Lua function to execute
    ///   - sandbox: The plugin's sandbox (used to create tables)
    ///   - context: The health check context
    /// - Returns: Array of findings from the check
    /// - Throws: PluginError if execution fails
    static func executeCheck(
        checkId: String,
        pluginId: String,
        function: Function,
        sandbox: LuaSandbox,
        context: HealthCheckContext
    ) throws -> [Finding] {
        // Convert context to Lua table using the sandbox
        let contextTable = self.createContextTable(sandbox: sandbox, context: context)

        // Call the check function
        let result = function.call([contextTable])

        switch result {
        case let .values(values):
            guard let findingsTable = values.first as? Table else {
                return []
            }
            return self.parseFindingsTable(findingsTable, checkId: checkId)

        case let .error(message):
            throw PluginError.executionFailed(
                id: pluginId,
                function: checkId,
                reason: message
            )
        }
    }

    // MARK: Private

    /// Creates a Lua table from the health check context.
    private static func createContextTable(sandbox: LuaSandbox, context: HealthCheckContext) -> Table {
        let table = sandbox.createTable()

        // Add deny rules
        let denyRulesTable = sandbox.createTable()
        for (index, rule) in context.allDenyRules.enumerated() {
            denyRulesTable[index + 1] = rule
        }
        table["denyRules"] = denyRulesTable

        // Add allow rules
        let allowRulesTable = sandbox.createTable()
        for (index, rule) in context.allAllowRules.enumerated() {
            allowRulesTable[index + 1] = rule
        }
        table["allowRules"] = allowRulesTable

        // Add MCP servers
        let mcpServersTable = sandbox.createTable()
        for (name, server) in context.allMCPServers {
            let serverTable = sandbox.createTable()

            // Add env vars if present
            if let env = server.env {
                let envTable = sandbox.createTable()
                for (key, value) in env {
                    envTable[key] = value
                }
                serverTable["env"] = envTable
            }

            // Add headers if present
            if let headers = server.headers {
                let headersTable = sandbox.createTable()
                for (key, value) in headers {
                    headersTable[key] = value
                }
                serverTable["headers"] = headersTable
            }

            mcpServersTable[name] = serverTable
        }
        table["mcpServers"] = mcpServersTable

        // Add boolean flags
        table["localSettingsExists"] = context.localSettingsExists
        table["mcpConfigExists"] = context.mcpConfigExists

        // Add global config file size
        if let size = context.globalConfigFileSize {
            table["globalConfigFileSize"] = Double(size)
        }

        // Add convenience flags for plugins
        let hasGlobalMCPServers = !(context.legacyConfig?.mcpServers?.isEmpty ?? true)
        table["hasGlobalMCPServers"] = hasGlobalMCPServers

        let hasHooks = (context.globalSettings?.hooks?.isEmpty == false)
            || (context.projectSettings?.hooks?.isEmpty == false)
            || (context.projectLocalSettings?.hooks?.isEmpty == false)
        table["hasHooks"] = hasHooks

        return table
    }

    /// Parses a Lua table of findings into Swift Finding objects.
    private static func parseFindingsTable(_ table: Table, checkId: String) -> [Finding] {
        var findings: [Finding] = []

        // Lua arrays are 1-indexed
        var index = 1
        while let findingValue = table[index] as? Table {
            if let finding = parseSingleFinding(findingValue) {
                findings.append(finding)
            }
            index += 1
        }

        return findings
    }

    /// Parses a single Lua finding table into a Swift Finding.
    private static func parseSingleFinding(_ table: Table) -> Finding? {
        // Extract severity
        guard let severityString = table["severity"] as? String else {
            return nil
        }
        let severity = self.parseSeverity(severityString)

        // Extract title
        guard let title = table["title"] as? String else {
            return nil
        }

        // Extract description
        guard let description = table["description"] as? String else {
            return nil
        }

        // Extract optional autoFix
        let autoFix = self.parseAutoFix(table["autoFix"])

        return Finding(
            severity: severity,
            title: title,
            description: description,
            autoFix: autoFix
        )
    }

    /// Converts a Lua severity string to a Swift Severity.
    private static func parseSeverity(_ string: String) -> Severity {
        switch string.lowercased() {
        case "critical",
             "security":
            .security
        case "warning":
            .warning
        case "suggestion":
            .suggestion
        case "info",
             "good":
            .good
        default:
            .suggestion
        }
    }

    /// Parses an autoFix table from Lua.
    private static func parseAutoFix(_ value: Value?) -> AutoFix? {
        guard let table = value as? Table else {
            return nil
        }

        guard let type = table["type"] as? String else {
            return nil
        }

        switch type {
        case "createLocalSettings":
            return .createLocalSettings
        case "addRule":
            if let rule = table["rule"] as? String {
                return .addToDenyList(pattern: rule)
            }
            return nil
        default:
            return nil
        }
    }
}
