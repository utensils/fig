use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

use super::mcp_server::MCPServer;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct MCPConfig {
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "mcpServers")]
    pub mcp_servers: Option<HashMap<String, MCPServer>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

impl MCPConfig {
    pub fn server_names(&self) -> Vec<String> {
        self.mcp_servers
            .as_ref()
            .map(|s| s.keys().cloned().collect())
            .unwrap_or_default()
    }

    pub fn server(&self, name: &str) -> Option<&MCPServer> {
        self.mcp_servers.as_ref()?.get(name)
    }

    pub fn server_count(&self) -> usize {
        self.mcp_servers.as_ref().map(|s| s.len()).unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mcp_config_multiple_servers() {
        let json = r#"{"mcpServers":{"github":{"command":"npx","args":["-y","@modelcontextprotocol/server-github"]},"remote":{"type":"http","url":"https://mcp.example.com/api"}},"version":"1.0"}"#;
        let parsed: MCPConfig = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.server_count(), 2);
        assert!(parsed.server("github").unwrap().is_stdio());
        assert!(parsed.server("remote").unwrap().is_http());
        assert_eq!(
            parsed.additional_properties.get("version"),
            Some(&Value::String("1.0".to_string()))
        );
    }

    #[test]
    fn test_mcp_config_round_trip() {
        let json = r#"{"mcpServers":{"github":{"command":"npx"}},"version":"1.0"}"#;
        let parsed: MCPConfig = serde_json::from_str(json).unwrap();
        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: MCPConfig = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_mcp_config_empty() {
        let parsed: MCPConfig = serde_json::from_str("{}").unwrap();
        assert_eq!(parsed.server_count(), 0);
        assert!(parsed.server_names().is_empty());
    }
}
