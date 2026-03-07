use std::collections::{HashMap, HashSet};
use std::path::Path;

use crate::error::ConfigFileError;
use crate::models::config_source::ConfigSource;
use crate::models::merged_settings::*;
use crate::models::claude_settings::ClaudeSettings;
use crate::services::config_file_manager::ConfigFileManager;

pub struct SettingsMergeService {
    config_manager: ConfigFileManager,
}

impl SettingsMergeService {
    pub fn new(config_manager: ConfigFileManager) -> Self {
        Self { config_manager }
    }

    pub fn merge_settings(&self, project_path: &Path) -> Result<MergedSettings, ConfigFileError> {
        let global = self.config_manager.read_global_settings()?;
        let shared = self.config_manager.read_project_settings(project_path)?;
        let local = self
            .config_manager
            .read_project_local_settings(project_path)?;
        Ok(Self::merge_from_loaded(
            global.as_ref(),
            shared.as_ref(),
            local.as_ref(),
        ))
    }

    pub fn merge_from_loaded(
        global: Option<&ClaudeSettings>,
        project_shared: Option<&ClaudeSettings>,
        project_local: Option<&ClaudeSettings>,
    ) -> MergedSettings {
        let tiers: Vec<(Option<&ClaudeSettings>, ConfigSource)> = vec![
            (global, ConfigSource::Global),
            (project_shared, ConfigSource::ProjectShared),
            (project_local, ConfigSource::ProjectLocal),
        ];

        MergedSettings {
            permissions: Self::merge_permissions(&tiers),
            env: Self::merge_env(&tiers),
            hooks: Self::merge_hooks(&tiers),
            disallowed_tools: Self::merge_disallowed_tools(&tiers),
            attribution: Self::merge_attribution(&tiers),
        }
    }

    fn merge_permissions(
        tiers: &[(Option<&ClaudeSettings>, ConfigSource)],
    ) -> MergedPermissions {
        let mut allow_entries: Vec<MergedValue<String>> = Vec::new();
        let mut deny_entries: Vec<MergedValue<String>> = Vec::new();
        let mut seen_allow = HashSet::new();
        let mut seen_deny = HashSet::new();

        for (settings, source) in tiers {
            let Some(settings) = settings else {
                continue;
            };
            let Some(permissions) = &settings.permissions else {
                continue;
            };

            if let Some(allow) = &permissions.allow {
                for pattern in allow {
                    if seen_allow.insert(pattern.clone()) {
                        allow_entries.push(MergedValue {
                            value: pattern.clone(),
                            source: *source,
                        });
                    }
                }
            }

            if let Some(deny) = &permissions.deny {
                for pattern in deny {
                    if seen_deny.insert(pattern.clone()) {
                        deny_entries.push(MergedValue {
                            value: pattern.clone(),
                            source: *source,
                        });
                    }
                }
            }
        }

        MergedPermissions {
            allow: allow_entries,
            deny: deny_entries,
        }
    }

    fn merge_env(
        tiers: &[(Option<&ClaudeSettings>, ConfigSource)],
    ) -> HashMap<String, MergedValue<String>> {
        let mut result: HashMap<String, MergedValue<String>> = HashMap::new();

        for (settings, source) in tiers {
            let Some(settings) = settings else {
                continue;
            };
            let Some(env) = &settings.env else {
                continue;
            };

            for (key, value) in env {
                result.insert(
                    key.clone(),
                    MergedValue {
                        value: value.clone(),
                        source: *source,
                    },
                );
            }
        }

        result
    }

    fn merge_hooks(tiers: &[(Option<&ClaudeSettings>, ConfigSource)]) -> MergedHooks {
        let mut result: HashMap<String, Vec<MergedValue<crate::models::HookGroup>>> =
            HashMap::new();

        for (settings, source) in tiers {
            let Some(settings) = settings else {
                continue;
            };
            let Some(hooks) = &settings.hooks else {
                continue;
            };

            for (event_name, hook_groups) in hooks {
                let existing = result.entry(event_name.clone()).or_default();
                for group in hook_groups {
                    existing.push(MergedValue {
                        value: group.clone(),
                        source: *source,
                    });
                }
            }
        }

        MergedHooks { hooks: result }
    }

    fn merge_disallowed_tools(
        tiers: &[(Option<&ClaudeSettings>, ConfigSource)],
    ) -> Vec<MergedValue<String>> {
        let mut result: Vec<MergedValue<String>> = Vec::new();
        let mut seen = HashSet::new();

        for (settings, source) in tiers {
            let Some(settings) = settings else {
                continue;
            };
            let Some(tools) = &settings.disallowed_tools else {
                continue;
            };

            for tool in tools {
                if seen.insert(tool.clone()) {
                    result.push(MergedValue {
                        value: tool.clone(),
                        source: *source,
                    });
                }
            }
        }

        result
    }

    fn merge_attribution(
        tiers: &[(Option<&ClaudeSettings>, ConfigSource)],
    ) -> Option<MergedValue<crate::models::Attribution>> {
        for (settings, source) in tiers.iter().rev() {
            if let Some(settings) = settings {
                if let Some(attribution) = &settings.attribution {
                    return Some(MergedValue {
                        value: attribution.clone(),
                        source: *source,
                    });
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Attribution, HookDefinition, HookGroup, Permissions};

    #[test]
    fn test_merge_all_none() {
        let merged = SettingsMergeService::merge_from_loaded(None, None, None);
        assert!(merged.permissions.allow.is_empty());
        assert!(merged.permissions.deny.is_empty());
        assert!(merged.env.is_empty());
        assert!(merged.hooks.event_names().is_empty());
        assert!(merged.disallowed_tools.is_empty());
        assert!(merged.attribution.is_none());
    }

    #[test]
    fn test_merge_permissions_union() {
        let global = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Bash(npm run *)".to_string()]),
                deny: Some(vec!["Read(.env)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };
        let shared = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Read(src/**)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };
        let local = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Write(docs/**)".to_string()]),
                deny: Some(vec!["Bash(rm *)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), Some(&shared), Some(&local));
        assert_eq!(merged.permissions.allow_patterns().len(), 3);
        assert_eq!(merged.permissions.deny_patterns().len(), 2);
    }

    #[test]
    fn test_merge_permissions_dedup() {
        let global = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Bash(*)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };
        let shared = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Bash(*)".to_string(), "Read(*)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), Some(&shared), None);
        assert_eq!(merged.permissions.allow_patterns().len(), 2);
    }

    #[test]
    fn test_merge_env_override() {
        let global = ClaudeSettings {
            env: Some(HashMap::from([
                ("DEBUG".to_string(), "false".to_string()),
                ("LOG_LEVEL".to_string(), "info".to_string()),
            ])),
            ..Default::default()
        };
        let local = ClaudeSettings {
            env: Some(HashMap::from([("DEBUG".to_string(), "true".to_string())])),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), None, Some(&local));
        assert_eq!(merged.effective_env().get("DEBUG"), Some(&"true"));
        assert_eq!(merged.effective_env().get("LOG_LEVEL"), Some(&"info"));
        assert_eq!(
            merged.env_source("DEBUG"),
            Some(ConfigSource::ProjectLocal)
        );
        assert_eq!(merged.env_source("LOG_LEVEL"), Some(ConfigSource::Global));
    }

    #[test]
    fn test_merge_env_union() {
        let global = ClaudeSettings {
            env: Some(HashMap::from([(
                "GLOBAL_VAR".to_string(),
                "global".to_string(),
            )])),
            ..Default::default()
        };
        let shared = ClaudeSettings {
            env: Some(HashMap::from([(
                "SHARED_VAR".to_string(),
                "shared".to_string(),
            )])),
            ..Default::default()
        };
        let local = ClaudeSettings {
            env: Some(HashMap::from([(
                "LOCAL_VAR".to_string(),
                "local".to_string(),
            )])),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), Some(&shared), Some(&local));
        assert_eq!(merged.effective_env().len(), 3);
    }

    #[test]
    fn test_merge_hooks_concatenate() {
        let global_hook = HookGroup {
            matcher: Some("Bash(*)".to_string()),
            hooks: Some(vec![HookDefinition {
                hook_type: Some("command".to_string()),
                command: Some("echo global".to_string()),
                ..Default::default()
            }]),
            ..Default::default()
        };
        let local_hook = HookGroup {
            matcher: Some("Read(*)".to_string()),
            hooks: Some(vec![HookDefinition {
                hook_type: Some("command".to_string()),
                command: Some("echo local".to_string()),
                ..Default::default()
            }]),
            ..Default::default()
        };

        let global = ClaudeSettings {
            hooks: Some(HashMap::from([(
                "PreToolUse".to_string(),
                vec![global_hook],
            )])),
            ..Default::default()
        };
        let local = ClaudeSettings {
            hooks: Some(HashMap::from([(
                "PreToolUse".to_string(),
                vec![local_hook],
            )])),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), None, Some(&local));
        let groups = merged.hooks.groups("PreToolUse").unwrap();
        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].source, ConfigSource::Global);
        assert_eq!(groups[1].source, ConfigSource::ProjectLocal);
    }

    #[test]
    fn test_merge_attribution_precedence() {
        let global = ClaudeSettings {
            attribution: Some(Attribution {
                commits: Some(false),
                pull_requests: Some(false),
                ..Default::default()
            }),
            ..Default::default()
        };
        let local = ClaudeSettings {
            attribution: Some(Attribution {
                commits: Some(true),
                pull_requests: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), None, Some(&local));
        let attr = merged.attribution.unwrap();
        assert_eq!(attr.value.commits, Some(true));
        assert_eq!(attr.source, ConfigSource::ProjectLocal);
    }

    #[test]
    fn test_merge_attribution_fallback() {
        let global = ClaudeSettings {
            attribution: Some(Attribution {
                commits: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), None, None);
        let attr = merged.attribution.unwrap();
        assert_eq!(attr.value.commits, Some(true));
        assert_eq!(attr.source, ConfigSource::Global);
    }

    #[test]
    fn test_merge_attribution_none() {
        let merged = SettingsMergeService::merge_from_loaded(
            Some(&ClaudeSettings::default()),
            None,
            Some(&ClaudeSettings::default()),
        );
        assert!(merged.attribution.is_none());
    }

    #[test]
    fn test_merge_source_tracking() {
        let global = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Bash(*)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };
        let local = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Read(*)".to_string()]),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged =
            SettingsMergeService::merge_from_loaded(Some(&global), None, Some(&local));
        let bash_entry = merged
            .permissions
            .allow
            .iter()
            .find(|v| v.value == "Bash(*)")
            .unwrap();
        let read_entry = merged
            .permissions
            .allow
            .iter()
            .find(|v| v.value == "Read(*)")
            .unwrap();
        assert_eq!(bash_entry.source, ConfigSource::Global);
        assert_eq!(read_entry.source, ConfigSource::ProjectLocal);
    }

    #[test]
    fn test_merge_from_loaded_integration() {
        let global = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Bash(npm run *)".to_string()]),
                deny: Some(vec!["Read(.env)".to_string()]),
                ..Default::default()
            }),
            env: Some(HashMap::from([
                ("LOG_LEVEL".to_string(), "info".to_string()),
                ("DEBUG".to_string(), "false".to_string()),
            ])),
            disallowed_tools: Some(vec!["DangerousTool".to_string()]),
            attribution: Some(Attribution {
                commits: Some(false),
                ..Default::default()
            }),
            ..Default::default()
        };

        let shared = ClaudeSettings {
            permissions: Some(Permissions {
                allow: Some(vec!["Read(src/**)".to_string()]),
                ..Default::default()
            }),
            env: Some(HashMap::from([(
                "API_URL".to_string(),
                "https://api.example.com".to_string(),
            )])),
            ..Default::default()
        };

        let local = ClaudeSettings {
            permissions: Some(Permissions {
                deny: Some(vec!["Bash(rm *)".to_string()]),
                ..Default::default()
            }),
            env: Some(HashMap::from([("DEBUG".to_string(), "true".to_string())])),
            attribution: Some(Attribution {
                commits: Some(true),
                pull_requests: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        };

        let merged = SettingsMergeService::merge_from_loaded(
            Some(&global),
            Some(&shared),
            Some(&local),
        );

        assert_eq!(merged.permissions.allow_patterns().len(), 2);
        assert_eq!(merged.permissions.deny_patterns().len(), 2);
        assert_eq!(merged.effective_env().get("DEBUG"), Some(&"true"));
        assert_eq!(
            merged.env_source("DEBUG"),
            Some(ConfigSource::ProjectLocal)
        );
        assert_eq!(merged.effective_env().get("LOG_LEVEL"), Some(&"info"));
        assert_eq!(
            merged.effective_env().get("API_URL"),
            Some(&"https://api.example.com")
        );
        assert!(merged.is_tool_disallowed("DangerousTool"));
        assert_eq!(
            merged.attribution.as_ref().unwrap().value.commits,
            Some(true)
        );
        assert_eq!(
            merged.attribution.as_ref().unwrap().source,
            ConfigSource::ProjectLocal
        );
    }
}
