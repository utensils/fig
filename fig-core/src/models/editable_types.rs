use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PermissionType {
    Allow,
    Deny,
}

impl PermissionType {
    pub fn label(&self) -> &str {
        match self {
            Self::Allow => "Allow",
            Self::Deny => "Deny",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EditablePermissionRule {
    pub id: Uuid,
    pub rule: String,
    pub permission_type: PermissionType,
}

impl EditablePermissionRule {
    pub fn new(rule: String, permission_type: PermissionType) -> Self {
        Self {
            id: Uuid::new_v4(),
            rule,
            permission_type,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EditableEnvironmentVariable {
    pub id: Uuid,
    pub key: String,
    pub value: String,
}

impl EditableEnvironmentVariable {
    pub fn new(key: String, value: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            key,
            value,
        }
    }

    pub fn is_sensitive_key(key: &str) -> bool {
        let upper = key.to_uppercase();
        ["TOKEN", "KEY", "SECRET", "PASSWORD"]
            .iter()
            .any(|pat| upper.contains(pat))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ToolType {
    Bash,
    Read,
    Write,
    Edit,
    Grep,
    Glob,
    WebFetch,
    Notebook,
    Custom,
}

impl ToolType {
    pub fn name(&self) -> &str {
        match self {
            Self::Bash => "Bash",
            Self::Read => "Read",
            Self::Write => "Write",
            Self::Edit => "Edit",
            Self::Grep => "Grep",
            Self::Glob => "Glob",
            Self::WebFetch => "WebFetch",
            Self::Notebook => "Notebook",
            Self::Custom => "Custom",
        }
    }

    pub fn placeholder(&self) -> &str {
        match self {
            Self::Bash => "npm run *, git *, etc.",
            Self::Read => "src/**, .env, config/*.json",
            Self::Write => "*.log, temp/*, dist/**",
            Self::Edit => "src/**/*.ts, package.json",
            Self::Grep => "*.ts, src/**",
            Self::Glob => "**/*.test.ts",
            Self::WebFetch => "https://api.example.com/*",
            Self::Notebook => "*.ipynb",
            Self::Custom => "Enter tool name...",
        }
    }

    pub fn all() -> &'static [ToolType] {
        &[
            Self::Bash,
            Self::Read,
            Self::Write,
            Self::Edit,
            Self::Grep,
            Self::Glob,
            Self::WebFetch,
            Self::Notebook,
            Self::Custom,
        ]
    }
}

pub struct PermissionPreset {
    pub id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
    pub rules: &'static [(&'static str, PermissionType)],
}

pub static PERMISSION_PRESETS: &[PermissionPreset] = &[
    PermissionPreset {
        id: "protect-env",
        name: "Protect .env files",
        description: "Prevent reading environment files",
        rules: &[
            ("Read(.env)", PermissionType::Deny),
            ("Read(.env.*)", PermissionType::Deny),
        ],
    },
    PermissionPreset {
        id: "allow-npm",
        name: "Allow npm scripts",
        description: "Allow running npm scripts",
        rules: &[("Bash(npm run *)", PermissionType::Allow)],
    },
    PermissionPreset {
        id: "allow-git",
        name: "Allow git operations",
        description: "Allow running git commands",
        rules: &[("Bash(git *)", PermissionType::Allow)],
    },
    PermissionPreset {
        id: "read-only",
        name: "Read-only mode",
        description: "Deny all write and edit operations",
        rules: &[
            ("Write", PermissionType::Deny),
            ("Edit", PermissionType::Deny),
        ],
    },
    PermissionPreset {
        id: "allow-read-src",
        name: "Allow reading source",
        description: "Allow reading all files in src directory",
        rules: &[("Read(src/**)", PermissionType::Allow)],
    },
    PermissionPreset {
        id: "deny-curl",
        name: "Block curl commands",
        description: "Prevent curl network requests",
        rules: &[("Bash(curl *)", PermissionType::Deny)],
    },
];

pub struct KnownEnvironmentVariable {
    pub name: &'static str,
    pub description: &'static str,
    pub default_value: Option<&'static str>,
}

impl KnownEnvironmentVariable {
    pub fn description_for(key: &str) -> Option<&'static str> {
        KNOWN_ENVIRONMENT_VARIABLES
            .iter()
            .find(|v| v.name == key)
            .map(|v| v.description)
    }
}

pub static KNOWN_ENVIRONMENT_VARIABLES: &[KnownEnvironmentVariable] = &[
    KnownEnvironmentVariable {
        name: "CLAUDE_CODE_MAX_OUTPUT_TOKENS",
        description: "Maximum tokens in Claude's response",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "BASH_DEFAULT_TIMEOUT_MS",
        description: "Default timeout for bash commands in milliseconds",
        default_value: Some("120000"),
    },
    KnownEnvironmentVariable {
        name: "CLAUDE_CODE_ENABLE_TELEMETRY",
        description: "Enable/disable telemetry (0 or 1)",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "OTEL_METRICS_EXPORTER",
        description: "OpenTelemetry metrics exporter configuration",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "DISABLE_TELEMETRY",
        description: "Disable all telemetry (0 or 1)",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
        description: "Reduce network calls by disabling non-essential traffic",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "ANTHROPIC_MODEL",
        description: "Override the default model used by Claude Code",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "ANTHROPIC_DEFAULT_SONNET_MODEL",
        description: "Default Sonnet model to use",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "ANTHROPIC_DEFAULT_OPUS_MODEL",
        description: "Default Opus model to use",
        default_value: None,
    },
    KnownEnvironmentVariable {
        name: "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        description: "Default Haiku model to use",
        default_value: None,
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_editable_rule_unique_ids() {
        let r1 = EditablePermissionRule::new("Bash(*)".to_string(), PermissionType::Allow);
        let r2 = EditablePermissionRule::new("Bash(*)".to_string(), PermissionType::Allow);
        assert_ne!(r1.id, r2.id);
    }

    #[test]
    fn test_editable_env_var_unique_ids() {
        let v1 = EditableEnvironmentVariable::new("KEY".to_string(), "val".to_string());
        let v2 = EditableEnvironmentVariable::new("KEY".to_string(), "val".to_string());
        assert_ne!(v1.id, v2.id);
    }

    #[test]
    fn test_permission_type_label() {
        assert_eq!(PermissionType::Allow.label(), "Allow");
        assert_eq!(PermissionType::Deny.label(), "Deny");
    }

    #[test]
    fn test_permission_presets_non_empty() {
        assert!(PERMISSION_PRESETS.len() >= 5);
        for preset in PERMISSION_PRESETS {
            assert!(!preset.name.is_empty());
            assert!(!preset.rules.is_empty());
        }
    }

    #[test]
    fn test_tool_type_placeholder() {
        for tool in ToolType::all() {
            assert!(!tool.name().is_empty());
            assert!(!tool.placeholder().is_empty());
        }
        assert_eq!(ToolType::all().len(), 9);
    }

    #[test]
    fn test_known_env_vars() {
        assert!(KNOWN_ENVIRONMENT_VARIABLES.len() >= 7);
        for var in KNOWN_ENVIRONMENT_VARIABLES {
            assert!(!var.name.is_empty());
            assert!(!var.description.is_empty());
        }
    }

    #[test]
    fn test_known_env_var_description_lookup() {
        assert_eq!(
            KnownEnvironmentVariable::description_for("ANTHROPIC_MODEL"),
            Some("Override the default model used by Claude Code")
        );
        assert_eq!(
            KnownEnvironmentVariable::description_for("NONEXISTENT"),
            None
        );
    }

    #[test]
    fn test_sensitive_key_detection() {
        assert!(EditableEnvironmentVariable::is_sensitive_key(
            "ANTHROPIC_API_KEY"
        ));
        assert!(EditableEnvironmentVariable::is_sensitive_key("AUTH_TOKEN"));
        assert!(EditableEnvironmentVariable::is_sensitive_key("DB_PASSWORD"));
        assert!(EditableEnvironmentVariable::is_sensitive_key(
            "CLIENT_SECRET"
        ));
        assert!(!EditableEnvironmentVariable::is_sensitive_key("LOG_LEVEL"));
        assert!(!EditableEnvironmentVariable::is_sensitive_key(
            "ANTHROPIC_MODEL"
        ));
    }

    #[test]
    fn test_preset_rules_valid_types() {
        for preset in PERMISSION_PRESETS {
            for (rule, ptype) in preset.rules {
                assert!(!rule.is_empty());
                assert!(*ptype == PermissionType::Allow || *ptype == PermissionType::Deny);
            }
        }
    }
}
