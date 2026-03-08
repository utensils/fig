use std::collections::HashMap;

use super::attribution::Attribution;
use super::config_source::ConfigSource;
use super::hook_group::HookGroup;

#[derive(Debug, Clone, PartialEq)]
pub struct MergedValue<T> {
    pub value: T,
    pub source: ConfigSource,
}

#[derive(Debug, Clone, Default)]
pub struct MergedPermissions {
    pub allow: Vec<MergedValue<String>>,
    pub deny: Vec<MergedValue<String>>,
}

impl MergedPermissions {
    pub fn allow_patterns(&self) -> Vec<&str> {
        self.allow.iter().map(|v| v.value.as_str()).collect()
    }

    pub fn deny_patterns(&self) -> Vec<&str> {
        self.deny.iter().map(|v| v.value.as_str()).collect()
    }
}

#[derive(Debug, Clone, Default)]
pub struct MergedHooks {
    pub hooks: HashMap<String, Vec<MergedValue<HookGroup>>>,
}

impl MergedHooks {
    pub fn event_names(&self) -> Vec<String> {
        let mut names: Vec<String> = self.hooks.keys().cloned().collect();
        names.sort();
        names
    }

    pub fn groups(&self, event: &str) -> Option<&Vec<MergedValue<HookGroup>>> {
        self.hooks.get(event)
    }
}

#[derive(Debug, Clone, Default)]
pub struct MergedSettings {
    pub permissions: MergedPermissions,
    pub env: HashMap<String, MergedValue<String>>,
    pub hooks: MergedHooks,
    pub disallowed_tools: Vec<MergedValue<String>>,
    pub attribution: Option<MergedValue<Attribution>>,
}

impl MergedSettings {
    pub fn effective_env(&self) -> HashMap<&str, &str> {
        self.env
            .iter()
            .map(|(k, v)| (k.as_str(), v.value.as_str()))
            .collect()
    }

    pub fn effective_disallowed_tools(&self) -> Vec<&str> {
        self.disallowed_tools
            .iter()
            .map(|v| v.value.as_str())
            .collect()
    }

    pub fn is_tool_disallowed(&self, tool: &str) -> bool {
        self.disallowed_tools.iter().any(|v| v.value == tool)
    }

    pub fn env_source(&self, key: &str) -> Option<ConfigSource> {
        self.env.get(key).map(|v| v.source)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_merged_value_stores_value_and_source() {
        let mv = MergedValue {
            value: "test".to_string(),
            source: ConfigSource::ProjectLocal,
        };
        assert_eq!(mv.value, "test");
        assert_eq!(mv.source, ConfigSource::ProjectLocal);
    }

    #[test]
    fn test_merged_permissions_patterns() {
        let perms = MergedPermissions {
            allow: vec![
                MergedValue {
                    value: "Bash(*)".to_string(),
                    source: ConfigSource::Global,
                },
                MergedValue {
                    value: "Read(src/**)".to_string(),
                    source: ConfigSource::ProjectShared,
                },
            ],
            deny: vec![MergedValue {
                value: "Read(.env)".to_string(),
                source: ConfigSource::Global,
            }],
        };
        assert_eq!(perms.allow_patterns(), vec!["Bash(*)", "Read(src/**)"]);
        assert_eq!(perms.deny_patterns(), vec!["Read(.env)"]);
    }

    #[test]
    fn test_merged_hooks_sorted_events() {
        let hooks = MergedHooks {
            hooks: HashMap::from([
                ("PreToolUse".to_string(), vec![]),
                ("PostToolUse".to_string(), vec![]),
                ("Notification".to_string(), vec![]),
            ]),
        };
        assert_eq!(
            hooks.event_names(),
            vec!["Notification", "PostToolUse", "PreToolUse"]
        );
    }

    #[test]
    fn test_merged_hooks_groups() {
        let hooks = MergedHooks {
            hooks: HashMap::from([(
                "PreToolUse".to_string(),
                vec![MergedValue {
                    value: HookGroup::default(),
                    source: ConfigSource::Global,
                }],
            )]),
        };
        assert!(hooks.groups("PreToolUse").is_some());
        assert!(hooks.groups("NonExistent").is_none());
    }

    #[test]
    fn test_merged_settings_effective_env() {
        let settings = MergedSettings {
            env: HashMap::from([
                (
                    "DEBUG".to_string(),
                    MergedValue {
                        value: "true".to_string(),
                        source: ConfigSource::ProjectLocal,
                    },
                ),
                (
                    "API_URL".to_string(),
                    MergedValue {
                        value: "https://api.example.com".to_string(),
                        source: ConfigSource::Global,
                    },
                ),
            ]),
            ..Default::default()
        };
        let env = settings.effective_env();
        assert_eq!(env.get("DEBUG"), Some(&"true"));
        assert_eq!(env.get("API_URL"), Some(&"https://api.example.com"));
    }

    #[test]
    fn test_merged_settings_is_tool_disallowed() {
        let settings = MergedSettings {
            disallowed_tools: vec![MergedValue {
                value: "DangerousTool".to_string(),
                source: ConfigSource::Global,
            }],
            ..Default::default()
        };
        assert!(settings.is_tool_disallowed("DangerousTool"));
        assert!(!settings.is_tool_disallowed("SafeTool"));
    }

    #[test]
    fn test_merged_settings_env_source() {
        let settings = MergedSettings {
            env: HashMap::from([(
                "DEBUG".to_string(),
                MergedValue {
                    value: "true".to_string(),
                    source: ConfigSource::ProjectLocal,
                },
            )]),
            ..Default::default()
        };
        assert_eq!(
            settings.env_source("DEBUG"),
            Some(ConfigSource::ProjectLocal)
        );
        assert_eq!(settings.env_source("MISSING"), None);
    }
}
