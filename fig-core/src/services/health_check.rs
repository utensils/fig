use crate::models::{ClaudeSettings, MergedSettings};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum FindingSeverity {
    Good,
    Suggestion,
    Warning,
    Security,
}

impl FindingSeverity {
    pub fn label(&self) -> &str {
        match self {
            Self::Good => "Good",
            Self::Suggestion => "Suggestion",
            Self::Warning => "Warning",
            Self::Security => "Security",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Finding {
    pub severity: FindingSeverity,
    pub title: String,
    pub description: String,
    pub check_name: String,
}

pub struct HealthCheckContext {
    pub global_settings: Option<ClaudeSettings>,
    pub project_settings: Option<ClaudeSettings>,
    pub merged: MergedSettings,
    pub has_local_settings: bool,
    pub has_project_mcp: bool,
}

pub trait HealthCheck {
    fn name(&self) -> &str;
    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding>;
}

pub fn run_all_checks(ctx: &HealthCheckContext) -> Vec<Finding> {
    let checks: Vec<Box<dyn HealthCheck>> = vec![
        Box::new(DenyListSecurityCheck),
        Box::new(BroadAllowRulesCheck),
        Box::new(MCPHardcodedSecretsCheck),
        Box::new(LocalSettingsCheck),
        Box::new(MCPScopingCheck),
        Box::new(HookSuggestionsCheck),
        Box::new(GoodPracticesCheck),
    ];

    let mut findings: Vec<Finding> = checks.iter().flat_map(|c| c.run(ctx)).collect();
    findings.sort_by(|a, b| b.severity.cmp(&a.severity));
    findings
}

pub struct DenyListSecurityCheck;

impl HealthCheck for DenyListSecurityCheck {
    fn name(&self) -> &str {
        "Deny List Security"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        let deny_patterns = ctx.merged.permissions.deny_patterns();
        let has_env_protection = deny_patterns.iter().any(|p| p.contains(".env"));

        if has_env_protection {
            vec![Finding {
                severity: FindingSeverity::Good,
                title: "Environment files protected".to_string(),
                description: "Deny rules prevent reading .env files.".to_string(),
                check_name: self.name().to_string(),
            }]
        } else {
            vec![Finding {
                severity: FindingSeverity::Security,
                title: "No .env file protection".to_string(),
                description: "Consider adding a deny rule for Read(.env) to protect sensitive environment files.".to_string(),
                check_name: self.name().to_string(),
            }]
        }
    }
}

pub struct BroadAllowRulesCheck;

impl HealthCheck for BroadAllowRulesCheck {
    fn name(&self) -> &str {
        "Broad Allow Rules"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        let broad_patterns = ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)"];
        let mut findings = Vec::new();

        for pattern in ctx.merged.permissions.allow_patterns() {
            if broad_patterns.contains(&pattern) {
                findings.push(Finding {
                    severity: FindingSeverity::Warning,
                    title: format!("Broad allow rule: {pattern}"),
                    description:
                        "This rule allows very broad access. Consider narrowing the scope."
                            .to_string(),
                    check_name: self.name().to_string(),
                });
            }
        }

        if findings.is_empty() {
            findings.push(Finding {
                severity: FindingSeverity::Good,
                title: "No overly broad allow rules".to_string(),
                description: "Permission rules are appropriately scoped.".to_string(),
                check_name: self.name().to_string(),
            });
        }

        findings
    }
}

pub struct MCPHardcodedSecretsCheck;

impl HealthCheck for MCPHardcodedSecretsCheck {
    fn name(&self) -> &str {
        "MCP Hardcoded Secrets"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        let secret_prefixes = ["sk-", "ghp_", "gho_", "AKIA", "Bearer "];
        let mut findings = Vec::new();

        let check_settings = |settings: &Option<ClaudeSettings>| -> Vec<String> {
            let mut issues = Vec::new();
            if let Some(ref s) = settings {
                if let Some(ref env) = s.env {
                    for (key, value) in env {
                        if secret_prefixes.iter().any(|p| value.starts_with(p)) {
                            issues.push(key.clone());
                        }
                    }
                }
            }
            issues
        };

        let global_issues = check_settings(&ctx.global_settings);
        let project_issues = check_settings(&ctx.project_settings);

        for key in global_issues.iter().chain(project_issues.iter()) {
            findings.push(Finding {
                severity: FindingSeverity::Security,
                title: format!("Possible hardcoded secret in {key}"),
                description:
                    "This value looks like an API key or token. Use environment variables instead."
                        .to_string(),
                check_name: self.name().to_string(),
            });
        }

        findings
    }
}

pub struct LocalSettingsCheck;

impl HealthCheck for LocalSettingsCheck {
    fn name(&self) -> &str {
        "Local Settings"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        if ctx.has_local_settings {
            return Vec::new();
        }
        vec![Finding {
            severity: FindingSeverity::Suggestion,
            title: "No local settings file".to_string(),
            description:
                "Consider creating a settings.local.json for personal overrides that aren't shared."
                    .to_string(),
            check_name: self.name().to_string(),
        }]
    }
}

pub struct MCPScopingCheck;

impl HealthCheck for MCPScopingCheck {
    fn name(&self) -> &str {
        "MCP Server Scoping"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        if !ctx.has_project_mcp {
            if let Some(ref settings) = ctx.global_settings {
                if settings.env.as_ref().map(|e| e.len()).unwrap_or(0) > 0 {
                    return vec![Finding {
                        severity: FindingSeverity::Suggestion,
                        title: "Consider project-scoped MCP servers".to_string(),
                        description:
                            "You have global config but no project .mcp.json. Project-specific servers belong in .mcp.json."
                                .to_string(),
                        check_name: self.name().to_string(),
                    }];
                }
            }
        }
        Vec::new()
    }
}

pub struct HookSuggestionsCheck;

impl HealthCheck for HookSuggestionsCheck {
    fn name(&self) -> &str {
        "Hook Suggestions"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        let has_hooks = !ctx.merged.hooks.event_names().is_empty();
        if has_hooks {
            return vec![Finding {
                severity: FindingSeverity::Good,
                title: "Hooks configured".to_string(),
                description: "You have lifecycle hooks set up for automation.".to_string(),
                check_name: self.name().to_string(),
            }];
        }
        vec![Finding {
            severity: FindingSeverity::Suggestion,
            title: "No hooks configured".to_string(),
            description:
                "Hooks can automate formatting, linting, and testing after Claude edits files."
                    .to_string(),
            check_name: self.name().to_string(),
        }]
    }
}

pub struct GoodPracticesCheck;

impl HealthCheck for GoodPracticesCheck {
    fn name(&self) -> &str {
        "Good Practices"
    }

    fn run(&self, ctx: &HealthCheckContext) -> Vec<Finding> {
        let mut findings = Vec::new();

        // Check for deny rules (good practice)
        if !ctx.merged.permissions.deny_patterns().is_empty() {
            findings.push(Finding {
                severity: FindingSeverity::Good,
                title: "Deny rules configured".to_string(),
                description: "You have explicit deny rules to restrict access.".to_string(),
                check_name: self.name().to_string(),
            });
        }

        // Check for disallowed tools
        if !ctx.merged.disallowed_tools.is_empty() {
            findings.push(Finding {
                severity: FindingSeverity::Good,
                title: "Disallowed tools configured".to_string(),
                description: "You have tools explicitly blocked.".to_string(),
                check_name: self.name().to_string(),
            });
        }

        findings
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{ConfigSource, MergedValue};
    use std::collections::HashMap;

    fn empty_context() -> HealthCheckContext {
        HealthCheckContext {
            global_settings: None,
            project_settings: None,
            merged: MergedSettings::default(),
            has_local_settings: false,
            has_project_mcp: false,
        }
    }

    #[test]
    fn test_deny_list_no_protection() {
        let ctx = empty_context();
        let findings = DenyListSecurityCheck.run(&ctx);
        assert!(findings
            .iter()
            .any(|f| f.severity == FindingSeverity::Security));
    }

    #[test]
    fn test_deny_list_with_protection() {
        let mut ctx = empty_context();
        ctx.merged.permissions.deny.push(MergedValue {
            value: "Read(.env)".to_string(),
            source: ConfigSource::Global,
        });
        let findings = DenyListSecurityCheck.run(&ctx);
        assert!(findings.iter().any(|f| f.severity == FindingSeverity::Good));
    }

    #[test]
    fn test_broad_allow_rules() {
        let mut ctx = empty_context();
        ctx.merged.permissions.allow.push(MergedValue {
            value: "Bash(*)".to_string(),
            source: ConfigSource::Global,
        });
        let findings = BroadAllowRulesCheck.run(&ctx);
        assert!(findings
            .iter()
            .any(|f| f.severity == FindingSeverity::Warning));
    }

    #[test]
    fn test_mcp_hardcoded_secrets() {
        let mut ctx = empty_context();
        let mut env = HashMap::new();
        env.insert("API_KEY".to_string(), "sk-abc123".to_string());
        ctx.global_settings = Some(ClaudeSettings {
            env: Some(env),
            ..Default::default()
        });
        let findings = MCPHardcodedSecretsCheck.run(&ctx);
        assert!(findings
            .iter()
            .any(|f| f.severity == FindingSeverity::Security));
    }

    #[test]
    fn test_local_settings_suggestion() {
        let ctx = empty_context();
        let findings = LocalSettingsCheck.run(&ctx);
        assert!(findings
            .iter()
            .any(|f| f.severity == FindingSeverity::Suggestion));

        let mut ctx2 = empty_context();
        ctx2.has_local_settings = true;
        let findings2 = LocalSettingsCheck.run(&ctx2);
        assert!(findings2.is_empty());
    }

    #[test]
    fn test_hook_suggestions_no_hooks() {
        let ctx = empty_context();
        let findings = HookSuggestionsCheck.run(&ctx);
        assert!(findings
            .iter()
            .any(|f| f.severity == FindingSeverity::Suggestion));
    }

    #[test]
    fn test_good_practices_with_deny() {
        let mut ctx = empty_context();
        ctx.merged.permissions.deny.push(MergedValue {
            value: "Write(.env)".to_string(),
            source: ConfigSource::Global,
        });
        let findings = GoodPracticesCheck.run(&ctx);
        assert!(findings.iter().any(|f| f.severity == FindingSeverity::Good));
    }

    #[test]
    fn test_run_all_checks() {
        let ctx = empty_context();
        let findings = run_all_checks(&ctx);
        assert!(!findings.is_empty());
        // Verify sorted by severity descending
        for window in findings.windows(2) {
            assert!(window[0].severity >= window[1].severity);
        }
    }
}
