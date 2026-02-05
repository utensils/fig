import Foundation
import OSLog

// MARK: - HealthCheck

/// Protocol for individual configuration health checks.
protocol HealthCheck: Sendable {
    /// Display name of this check.
    var name: String { get }

    /// Runs the check against the provided context and returns any findings.
    func check(context: HealthCheckContext) -> [Finding]
}

// MARK: - DenyListSecurityCheck

/// Checks that sensitive files like `.env` and `secrets/` are in the deny list.
struct DenyListSecurityCheck: HealthCheck {
    let name = "Deny List Security"

    func check(context: HealthCheckContext) -> [Finding] {
        var findings: [Finding] = []
        let denyRules = context.allDenyRules

        // Check for .env files
        let hasEnvDeny = denyRules.contains { rule in
            rule.contains(".env")
        }
        if !hasEnvDeny {
            findings.append(Finding(
                severity: .security,
                title: ".env files not in deny list",
                description: "Environment files often contain secrets like API keys and passwords. " +
                    "Add a deny rule to prevent Claude from reading them.",
                autoFix: .addToDenyList(pattern: "Read(.env)")
            ))
        }

        // Check for secrets/ directory
        let hasSecretsDeny = denyRules.contains { rule in
            rule.contains("secrets")
        }
        if !hasSecretsDeny {
            findings.append(Finding(
                severity: .security,
                title: "secrets/ directory not in deny list",
                description: "The secrets/ directory may contain sensitive credentials. " +
                    "Add a deny rule to prevent Claude from accessing it.",
                autoFix: .addToDenyList(pattern: "Read(secrets/**)")
            ))
        }

        return findings
    }
}

// MARK: - BroadAllowRulesCheck

/// Checks for overly broad allow rules that may pose security risks.
struct BroadAllowRulesCheck: HealthCheck {
    // MARK: Internal

    let name = "Broad Allow Rules"

    func check(context: HealthCheckContext) -> [Finding] {
        let allowRules = context.allAllowRules

        return Self.broadPatterns.compactMap { broad in
            if allowRules.contains(broad.pattern) {
                return Finding(
                    severity: .warning,
                    title: "Overly broad allow rule: \(broad.pattern)",
                    description: "\(broad.description). Consider using more specific patterns " +
                        "to limit what Claude can access."
                )
            }
            return nil
        }
    }

    // MARK: Private

    /// Patterns considered overly broad.
    private static let broadPatterns: [(pattern: String, description: String)] = [
        ("Bash(*)", "Allows any Bash command without restriction"),
        ("Read(*)", "Allows reading any file without restriction"),
        ("Write(*)", "Allows writing to any file without restriction"),
        ("Edit(*)", "Allows editing any file without restriction"),
    ]
}

// MARK: - GlobalConfigSizeCheck

/// Checks if the global config file is too large (performance issue).
struct GlobalConfigSizeCheck: HealthCheck {
    // MARK: Internal

    let name = "Global Config Size"

    func check(context: HealthCheckContext) -> [Finding] {
        guard let size = context.globalConfigFileSize, size > Self.sizeThreshold else {
            return []
        }

        let megabytes = Double(size) / (1024 * 1024)
        return [Finding(
            severity: .warning,
            title: "~/.claude.json is large (\(String(format: "%.1f", megabytes)) MB)",
            description: "A large global config file can slow down Claude Code startup. " +
                "Consider cleaning up old project entries or conversation history."
        )]
    }

    // MARK: Private

    /// Threshold in bytes (5 MB).
    private static let sizeThreshold: Int64 = 5 * 1024 * 1024
}

// MARK: - MCPHardcodedSecretsCheck

/// Checks for MCP servers with hardcoded secrets in their configuration.
struct MCPHardcodedSecretsCheck: HealthCheck {
    // MARK: Internal

    let name = "MCP Hardcoded Secrets"

    func check(context: HealthCheckContext) -> [Finding] {
        var findings: [Finding] = []

        for (name, server) in context.allMCPServers {
            // Check env vars for hardcoded secrets
            if let env = server.env {
                for (key, value) in env {
                    if self.looksLikeSecret(key: key, value: value) {
                        findings.append(Finding(
                            severity: .warning,
                            title: "Hardcoded secret in MCP server '\(name)'",
                            description: "The environment variable '\(key)' appears to contain a " +
                                "hardcoded secret. Consider using environment variable references instead."
                        ))
                    }
                }
            }

            // Check HTTP headers for hardcoded secrets
            if let headers = server.headers {
                for (key, value) in headers {
                    if self.looksLikeSecret(key: key, value: value) {
                        findings.append(Finding(
                            severity: .warning,
                            title: "Hardcoded secret in MCP server '\(name)' headers",
                            description: "The header '\(key)' appears to contain a hardcoded secret. " +
                                "Consider using environment variable references instead."
                        ))
                    }
                }
            }
        }

        return findings
    }

    // MARK: Private

    /// Patterns that suggest a value is a secret.
    private static let secretPatterns: [String] = [
        "sk-", "sk_", "ghp_", "gho_", "ghu_", "ghs_",
        "xoxb-", "xoxp-", "xoxs-",
        "AKIA", "Bearer ",
        "-----BEGIN",
    ]

    /// Environment variable names that commonly hold secrets.
    private static let secretKeyNames: [String] = [
        "TOKEN", "SECRET", "KEY", "PASSWORD", "CREDENTIAL",
        "AUTH", "API_KEY", "APIKEY", "PRIVATE",
    ]

    private func looksLikeSecret(key: String, value: String) -> Bool {
        let upperKey = key.uppercased()

        // Check if the key name suggests it's a secret
        let keyIsSecret = Self.secretKeyNames.contains { upperKey.contains($0) }

        // Check if the value looks like a known secret format
        let valueIsSecret = Self.secretPatterns.contains { value.hasPrefix($0) }

        // A short value is unlikely to be a secret
        let isLongEnough = value.count >= 8

        return (keyIsSecret && isLongEnough) || valueIsSecret
    }
}

// MARK: - LocalSettingsCheck

/// Suggests creating `settings.local.json` for personal overrides.
struct LocalSettingsCheck: HealthCheck {
    let name = "Local Settings"

    func check(context: HealthCheckContext) -> [Finding] {
        if context.localSettingsExists {
            return []
        }

        return [Finding(
            severity: .suggestion,
            title: "No settings.local.json",
            description: "Create a local settings file for personal overrides that won't be " +
                "committed to version control. This is useful for developer-specific " +
                "environment variables or permission tweaks.",
            autoFix: .createLocalSettings
        )]
    }
}

// MARK: - MCPScopingCheck

/// Suggests creating a project `.mcp.json` when global MCP servers exist.
struct MCPScopingCheck: HealthCheck {
    let name = "MCP Scoping"

    func check(context: HealthCheckContext) -> [Finding] {
        let hasGlobalServers = !(context.legacyConfig?.mcpServers?.isEmpty ?? true)
        let hasProjectMCP = context.mcpConfigExists

        if hasGlobalServers, !hasProjectMCP {
            return [Finding(
                severity: .suggestion,
                title: "Global MCP servers without project scoping",
                description: "You have global MCP servers configured but no project-level .mcp.json. " +
                    "Consider creating a project-scoped MCP configuration for better isolation."
            )]
        }

        return []
    }
}

// MARK: - HookSuggestionsCheck

/// Suggests hooks for common development patterns.
struct HookSuggestionsCheck: HealthCheck {
    let name = "Hook Suggestions"

    func check(context: HealthCheckContext) -> [Finding] {
        // Only suggest if there are no hooks configured at all
        let hasAnyHooks = (context.globalSettings?.hooks?.isEmpty == false)
            || (context.projectSettings?.hooks?.isEmpty == false)
            || (context.projectLocalSettings?.hooks?.isEmpty == false)

        if hasAnyHooks {
            return []
        }

        return [Finding(
            severity: .suggestion,
            title: "No hooks configured",
            description: "Hooks let you run commands before or after Claude uses tools. " +
                "Common uses include running formatters after file edits " +
                "or linters before committing code."
        )]
    }
}

// MARK: - GoodPracticesCheck

/// Reports good practices already in place (positive reinforcement).
struct GoodPracticesCheck: HealthCheck {
    let name = "Good Practices"

    func check(context: HealthCheckContext) -> [Finding] {
        var findings: [Finding] = []

        let denyRules = context.allDenyRules

        // Check for .env in deny list
        if denyRules.contains(where: { $0.contains(".env") }) {
            findings.append(Finding(
                severity: .good,
                title: "Sensitive files protected",
                description: "Your deny list includes rules to protect .env files from being read."
            ))
        }

        // Check for secrets in deny list
        if denyRules.contains(where: { $0.contains("secrets") }) {
            findings.append(Finding(
                severity: .good,
                title: "Secrets directory protected",
                description: "Your deny list includes rules to protect the secrets directory."
            ))
        }

        // Check for local settings
        if context.localSettingsExists {
            findings.append(Finding(
                severity: .good,
                title: "Local settings configured",
                description: "You have a settings.local.json for personal overrides."
            ))
        }

        // Check for project MCP config
        if context.mcpConfigExists {
            findings.append(Finding(
                severity: .good,
                title: "Project-scoped MCP servers",
                description: "MCP servers are configured at the project level for better isolation."
            ))
        }

        // Check for hooks
        let hasHooks = (context.projectSettings?.hooks?.isEmpty == false)
            || (context.projectLocalSettings?.hooks?.isEmpty == false)
        if hasHooks {
            findings.append(Finding(
                severity: .good,
                title: "Hooks configured",
                description: "Lifecycle hooks are set up for automated workflows."
            ))
        }

        // Check for scoped permissions
        let allowRules = context.allAllowRules
        let hasScopedRules = allowRules.contains { rule in
            // Rules with specific paths or patterns are considered scoped
            rule.contains("/") || rule.contains("**")
        }
        if hasScopedRules {
            findings.append(Finding(
                severity: .good,
                title: "Scoped permission rules",
                description: "Permission rules use specific path patterns for fine-grained access control."
            ))
        }

        return findings
    }
}

// MARK: - ConfigHealthCheckService

/// Service that runs all health checks and returns aggregated findings.
enum ConfigHealthCheckService {
    /// All registered built-in Swift health checks, run in order.
    static let checks: [any HealthCheck] = [
        DenyListSecurityCheck(),
        BroadAllowRulesCheck(),
        GlobalConfigSizeCheck(),
        MCPHardcodedSecretsCheck(),
        LocalSettingsCheck(),
        MCPScopingCheck(),
        HookSuggestionsCheck(),
        GoodPracticesCheck(),
    ]

    /// Runs all health checks and returns findings sorted by severity.
    ///
    /// This synchronous version only runs built-in Swift checks.
    /// Use `runAllChecksAsync` to include plugin health checks.
    ///
    /// - Parameter context: The health check context
    /// - Returns: Array of findings from built-in Swift checks only
    static func runAllChecks(context: HealthCheckContext) -> [Finding] {
        var findings: [Finding] = []

        // Run built-in Swift checks
        for check in self.checks {
            let results = check.check(context: context)
            findings.append(contentsOf: results)
        }

        // Sort by severity (security first, then warning, suggestion, good)
        findings.sort { $0.severity < $1.severity }

        Log.general.info("Health check completed: \(findings.count) findings")
        return findings
    }

    /// Runs all health checks including plugin-registered checks.
    ///
    /// This async method runs both built-in Swift checks and any health checks
    /// registered by Lua plugins through `LuaPluginService`.
    ///
    /// - Parameter context: The health check context
    /// - Returns: Array of findings from all checks, sorted by severity
    static func runAllChecksAsync(context: HealthCheckContext) async -> [Finding] {
        var findings: [Finding] = []

        // Run built-in Swift checks
        for check in self.checks {
            let results = check.check(context: context)
            findings.append(contentsOf: results)
        }

        // Run plugin health checks
        let pluginFindings = await LuaPluginService.shared.executeHealthChecks(context: context)
        findings.append(contentsOf: pluginFindings)

        // Sort by severity (security first, then warning, suggestion, good)
        findings.sort { $0.severity < $1.severity }

        let pluginCount = pluginFindings.count
        Log.general.info("Health check completed: \(findings.count) findings (\(pluginCount) from plugins)")
        return findings
    }
}
