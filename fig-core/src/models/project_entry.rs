use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

use super::mcp_server::MCPServer;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct ProjectEntry {
    #[serde(skip)]
    pub path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "allowedTools")]
    pub allowed_tools: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "hasTrustDialogAccepted")]
    pub has_trust_dialog_accepted: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub history: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "mcpServers")]
    pub mcp_servers: Option<HashMap<String, MCPServer>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

impl ProjectEntry {
    pub fn name(&self) -> Option<&str> {
        self.path
            .as_ref()
            .and_then(|p| std::path::Path::new(p).file_name()?.to_str())
    }

    pub fn has_mcp_servers(&self) -> bool {
        self.mcp_servers
            .as_ref()
            .map(|s| !s.is_empty())
            .unwrap_or(false)
    }

    pub fn mcp_server_count(&self) -> usize {
        self.mcp_servers.as_ref().map(|s| s.len()).unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_project_entry_round_trip() {
        let json = r#"{"allowedTools":["Bash","Read","Write"],"hasTrustDialogAccepted":true,"history":["conv-1","conv-2"],"mcpServers":{"local":{"command":"node","args":["server.js"]}},"customData":{"nested":"value"}}"#;
        let parsed: ProjectEntry = serde_json::from_str(json).unwrap();
        assert_eq!(
            parsed.allowed_tools,
            Some(vec![
                "Bash".to_string(),
                "Read".to_string(),
                "Write".to_string()
            ])
        );
        assert_eq!(parsed.has_trust_dialog_accepted, Some(true));
        assert!(parsed.has_mcp_servers());
        assert_eq!(parsed.mcp_server_count(), 1);
        assert!(parsed.additional_properties.contains_key("customData"));

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: ProjectEntry = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_project_entry_name_extraction() {
        let mut entry = ProjectEntry::default();
        entry.path = Some("/Users/test/projects/my-app".to_string());
        assert_eq!(entry.name(), Some("my-app"));
    }

    #[test]
    fn test_project_entry_serde_skip_path() {
        let mut entry = ProjectEntry::default();
        entry.path = Some("/some/path".to_string());
        entry.allowed_tools = Some(vec!["Bash".to_string()]);
        let json = serde_json::to_string(&entry).unwrap();
        assert!(!json.contains("/some/path"));
        assert!(json.contains("allowedTools"));
    }
}
