-- Built-in Security Health Checks
-- Checks for common security issues in Claude Code configuration

-- Deny List Security Check
-- Ensures sensitive files like .env and secrets/ are in the deny list
fig.health.registerCheck("DenyListSecurity", function(context)
    local findings = {}
    local denyRules = context.denyRules or {}

    -- Check for .env files
    local hasEnvDeny = false
    for _, rule in ipairs(denyRules) do
        if string.find(rule, ".env", 1, true) then
            hasEnvDeny = true
            break
        end
    end

    if not hasEnvDeny then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.CRITICAL,
            title = ".env files not in deny list",
            description = "Environment files often contain secrets like API keys and passwords. Add a deny rule to prevent Claude from reading them.",
            autoFix = fig.health.autoFix.addRule("Read(.env)")
        }))
    end

    -- Check for secrets/ directory
    local hasSecretsDeny = false
    for _, rule in ipairs(denyRules) do
        if string.find(rule, "secrets", 1, true) then
            hasSecretsDeny = true
            break
        end
    end

    if not hasSecretsDeny then
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.CRITICAL,
            title = "secrets/ directory not in deny list",
            description = "The secrets/ directory may contain sensitive credentials. Add a deny rule to prevent Claude from accessing it.",
            autoFix = fig.health.autoFix.addRule("Read(secrets/**)")
        }))
    end

    return findings
end)

-- Broad Allow Rules Check
-- Checks for overly broad allow rules that may pose security risks
fig.health.registerCheck("BroadAllowRules", function(context)
    local findings = {}
    local allowRules = context.allowRules or {}

    local broadPatterns = {
        { pattern = "Bash(*)", description = "Allows any Bash command without restriction" },
        { pattern = "Read(*)", description = "Allows reading any file without restriction" },
        { pattern = "Write(*)", description = "Allows writing to any file without restriction" },
        { pattern = "Edit(*)", description = "Allows editing any file without restriction" }
    }

    for _, broad in ipairs(broadPatterns) do
        for _, rule in ipairs(allowRules) do
            if rule == broad.pattern then
                table.insert(findings, fig.health.finding({
                    severity = fig.health.severity.WARNING,
                    title = "Overly broad allow rule: " .. broad.pattern,
                    description = broad.description .. ". Consider using more specific patterns to limit what Claude can access."
                }))
                break
            end
        end
    end

    return findings
end)

-- MCP Hardcoded Secrets Check
-- Checks for MCP servers with hardcoded secrets in their configuration
fig.health.registerCheck("MCPHardcodedSecrets", function(context)
    local findings = {}
    local mcpServers = context.mcpServers or {}

    -- Patterns that suggest a value is a secret
    local secretPrefixes = {
        "sk-", "sk_", "ghp_", "gho_", "ghu_", "ghs_",
        "xoxb-", "xoxp-", "xoxs-",
        "AKIA", "Bearer ",
        "-----BEGIN"
    }

    -- Environment variable names that commonly hold secrets
    local secretKeyNames = {
        "TOKEN", "SECRET", "KEY", "PASSWORD", "CREDENTIAL",
        "AUTH", "API_KEY", "APIKEY", "PRIVATE"
    }

    local function looksLikeSecret(key, value)
        local upperKey = string.upper(key)

        -- Check if the key name suggests it's a secret
        local keyIsSecret = false
        for _, secretName in ipairs(secretKeyNames) do
            if string.find(upperKey, secretName, 1, true) then
                keyIsSecret = true
                break
            end
        end

        -- Check if the value looks like a known secret format
        local valueIsSecret = false
        for _, prefix in ipairs(secretPrefixes) do
            if string.sub(value, 1, #prefix) == prefix then
                valueIsSecret = true
                break
            end
        end

        -- A short value is unlikely to be a secret
        local isLongEnough = #value >= 8

        return (keyIsSecret and isLongEnough) or valueIsSecret
    end

    for name, server in pairs(mcpServers) do
        -- Check env vars for hardcoded secrets
        if server.env then
            for key, value in pairs(server.env) do
                if type(value) == "string" and looksLikeSecret(key, value) then
                    table.insert(findings, fig.health.finding({
                        severity = fig.health.severity.WARNING,
                        title = "Hardcoded secret in MCP server '" .. name .. "'",
                        description = "The environment variable '" .. key .. "' appears to contain a hardcoded secret. Consider using environment variable references instead."
                    }))
                end
            end
        end

        -- Check HTTP headers for hardcoded secrets
        if server.headers then
            for key, value in pairs(server.headers) do
                if type(value) == "string" and looksLikeSecret(key, value) then
                    table.insert(findings, fig.health.finding({
                        severity = fig.health.severity.WARNING,
                        title = "Hardcoded secret in MCP server '" .. name .. "' headers",
                        description = "The header '" .. key .. "' appears to contain a hardcoded secret. Consider using environment variable references instead."
                    }))
                end
            end
        end
    end

    return findings
end)

-- Global Config Size Check
-- Checks if the global config file is too large (performance issue)
fig.health.registerCheck("GlobalConfigSize", function(context)
    local findings = {}
    local sizeBytes = context.globalConfigFileSize or 0
    local sizeThreshold = 5 * 1024 * 1024 -- 5 MB

    if sizeBytes > sizeThreshold then
        local megabytes = sizeBytes / (1024 * 1024)
        table.insert(findings, fig.health.finding({
            severity = fig.health.severity.WARNING,
            title = string.format("~/.claude.json is large (%.1f MB)", megabytes),
            description = "A large global config file can slow down Claude Code startup. Consider cleaning up old project entries or conversation history."
        }))
    end

    return findings
end)

fig.log.info("Security health checks registered")
