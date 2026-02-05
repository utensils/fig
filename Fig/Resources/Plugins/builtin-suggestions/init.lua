-- Built-in Configuration Suggestion Health Checks
-- Provides helpful suggestions for improving Claude Code configuration

-- Local Settings Check
-- Suggests creating settings.local.json for personal overrides
fig.health.registerCheck("LocalSettings", function(context)
    local findings = {}

    if not context.localSettingsExists then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.SUGGESTION,
            title = "No settings.local.json",
            description = "Create a local settings file for personal overrides that won't be committed to version control. This is useful for developer-specific environment variables or permission tweaks.",
            autoFix = fig.health.autoFix.createLocalSettings()
        }))
    end

    return findings
end)

-- MCP Scoping Check
-- Suggests creating a project .mcp.json when global MCP servers exist
fig.health.registerCheck("MCPScoping", function(context)
    local findings = {}
    local hasGlobalServers = context.hasGlobalMCPServers or false
    local hasProjectMCP = context.mcpConfigExists or false

    if hasGlobalServers and not hasProjectMCP then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.SUGGESTION,
            title = "Global MCP servers without project scoping",
            description = "You have global MCP servers configured but no project-level .mcp.json. Consider creating a project-scoped MCP configuration for better isolation."
        }))
    end

    return findings
end)

-- Hook Suggestions Check
-- Suggests hooks for common development patterns
fig.health.registerCheck("HookSuggestions", function(context)
    local findings = {}
    local hasAnyHooks = context.hasHooks or false

    if not hasAnyHooks then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.SUGGESTION,
            title = "No hooks configured",
            description = "Hooks let you run commands before or after Claude uses tools. Common uses include running formatters after file edits or linters before committing code."
        }))
    end

    return findings
end)

fig.log.info("Suggestion health checks registered")
