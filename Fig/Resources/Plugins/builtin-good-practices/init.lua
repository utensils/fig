-- Built-in Good Practices Health Checks
-- Reports good practices already in place (positive reinforcement)

fig.health.registerCheck("GoodPractices", function(context)
    local findings = {}
    local denyRules = context.denyRules or {}
    local allowRules = context.allowRules or {}

    -- Check for .env in deny list
    for _, rule in ipairs(denyRules) do
        if string.find(rule, ".env", 1, true) then
            table.insert(findings, fig.health.finding({
                severity = fig.health.severity.INFO,
                title = "Sensitive files protected",
                description = "Your deny list includes rules to protect .env files from being read."
            }))
            break
        end
    end

    -- Check for secrets in deny list
    for _, rule in ipairs(denyRules) do
        if string.find(rule, "secrets", 1, true) then
            table.insert(findings, fig.health.finding({
                severity = fig.health.severity.INFO,
                title = "Secrets directory protected",
                description = "Your deny list includes rules to protect the secrets directory."
            }))
            break
        end
    end

    -- Check for local settings
    if context.localSettingsExists then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.INFO,
            title = "Local settings configured",
            description = "You have a settings.local.json for personal overrides."
        }))
    end

    -- Check for project MCP config
    if context.mcpConfigExists then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.INFO,
            title = "Project-scoped MCP servers",
            description = "MCP servers are configured at the project level for better isolation."
        }))
    end

    -- Check for hooks
    if context.hasHooks then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.INFO,
            title = "Hooks configured",
            description = "Lifecycle hooks are set up for automated workflows."
        }))
    end

    -- Check for scoped permissions
    for _, rule in ipairs(allowRules) do
        -- Rules with specific paths or patterns are considered scoped
        if string.find(rule, "/", 1, true) or string.find(rule, "**", 1, true) then
            table.insert(findings, fig.health.finding({
                severity = fig.health.severity.INFO,
                title = "Scoped permission rules",
                description = "Permission rules use specific path patterns for fine-grained access control."
            }))
            break
        end
    end

    return findings
end)

fig.log.info("Good practices health checks registered")
