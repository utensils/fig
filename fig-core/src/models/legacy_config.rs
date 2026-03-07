use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

use super::mcp_server::MCPServer;
use super::project_entry::ProjectEntry;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct LegacyConfig {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub projects: Option<HashMap<String, ProjectEntry>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "customApiKeyResponses")]
    pub custom_api_key_responses: Option<HashMap<String, Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preferences: Option<HashMap<String, Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "mcpServers")]
    pub mcp_servers: Option<HashMap<String, MCPServer>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

impl LegacyConfig {
    pub fn project_paths(&self) -> Vec<String> {
        self.projects
            .as_ref()
            .map(|p| p.keys().cloned().collect())
            .unwrap_or_default()
    }

    pub fn all_projects(&self) -> Vec<ProjectEntry> {
        self.projects
            .as_ref()
            .map(|p| {
                p.iter()
                    .map(|(path, entry)| {
                        let mut e = entry.clone();
                        e.path = Some(path.clone());
                        e
                    })
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn global_server_names(&self) -> Vec<String> {
        self.mcp_servers
            .as_ref()
            .map(|s| s.keys().cloned().collect())
            .unwrap_or_default()
    }

    pub fn project(&self, path: &str) -> Option<ProjectEntry> {
        self.projects.as_ref()?.get(path).map(|entry| {
            let mut e = entry.clone();
            e.path = Some(path.to_string());
            e
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LEGACY_CONFIG_JSON: &str = r#"{"projects":{"/path/to/project":{"allowedTools":["Bash","Read"],"hasTrustDialogAccepted":true}},"customApiKeyResponses":{"key1":"response1"},"preferences":{"theme":"dark"},"mcpServers":{"global-server":{"command":"npx","args":["server"]}},"analytics":false}"#;

    #[test]
    fn test_legacy_config_round_trip() {
        let parsed: LegacyConfig = serde_json::from_str(LEGACY_CONFIG_JSON).unwrap();
        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: LegacyConfig = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_all_projects_populates_paths() {
        let parsed: LegacyConfig = serde_json::from_str(LEGACY_CONFIG_JSON).unwrap();
        let projects = parsed.all_projects();
        assert_eq!(projects.len(), 1);
        assert_eq!(projects[0].path, Some("/path/to/project".to_string()));
    }

    #[test]
    fn test_legacy_config_project_lookup() {
        let parsed: LegacyConfig = serde_json::from_str(LEGACY_CONFIG_JSON).unwrap();
        let project = parsed.project("/path/to/project").unwrap();
        assert_eq!(project.has_trust_dialog_accepted, Some(true));
        assert_eq!(project.path, Some("/path/to/project".to_string()));
    }

    #[test]
    fn test_legacy_config_global_servers() {
        let parsed: LegacyConfig = serde_json::from_str(LEGACY_CONFIG_JSON).unwrap();
        let names = parsed.global_server_names();
        assert!(names.contains(&"global-server".to_string()));
    }

    #[test]
    fn test_legacy_config_preserves_unknown_fields() {
        let parsed: LegacyConfig = serde_json::from_str(LEGACY_CONFIG_JSON).unwrap();
        assert_eq!(
            parsed.additional_properties.get("analytics"),
            Some(&Value::Bool(false))
        );
    }
}
