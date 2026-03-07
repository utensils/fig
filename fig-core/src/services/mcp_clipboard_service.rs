use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::error::FigError;
use crate::models::editable_types::EditableEnvironmentVariable;
use crate::models::{MCPConfig, MCPServer};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShareableServerConfig {
    #[serde(rename = "mcpServers")]
    pub mcp_servers: HashMap<String, MCPServer>,
}

pub fn export_to_json(servers: &[(&str, &MCPServer)], redact_sensitive: bool) -> String {
    let mut map = HashMap::new();
    for (name, server) in servers {
        let s = if redact_sensitive {
            redact_server(server)
        } else {
            (*server).clone()
        };
        map.insert(name.to_string(), s);
    }
    let config = ShareableServerConfig { mcp_servers: map };
    serde_json::to_string_pretty(&config).unwrap_or_default()
}

pub fn import_from_json(json_str: &str) -> Result<Vec<(String, MCPServer)>, FigError> {
    // Try ShareableServerConfig format first
    if let Ok(config) = serde_json::from_str::<ShareableServerConfig>(json_str) {
        let mut servers: Vec<_> = config.mcp_servers.into_iter().collect();
        servers.sort_by(|(a, _), (b, _)| a.cmp(b));
        return Ok(servers);
    }

    // Try MCPConfig format (same structure but may have additional fields)
    if let Ok(config) = serde_json::from_str::<MCPConfig>(json_str) {
        if let Some(servers_map) = config.mcp_servers {
            let mut servers: Vec<_> = servers_map.into_iter().collect();
            servers.sort_by(|(a, _), (b, _)| a.cmp(b));
            return Ok(servers);
        }
    }

    Err(FigError::Other(
        "Invalid JSON: expected an object with 'mcpServers' key.".to_string(),
    ))
}

pub fn redact_server(server: &MCPServer) -> MCPServer {
    let mut redacted = server.clone();
    if let Some(ref mut env) = redacted.env {
        for (key, value) in env.iter_mut() {
            if EditableEnvironmentVariable::is_sensitive_key(key) {
                *value = "REDACTED".to_string();
            }
        }
    }
    if let Some(ref mut headers) = redacted.headers {
        for (key, value) in headers.iter_mut() {
            let lower = key.to_lowercase();
            if lower.contains("authorization") || lower.contains("token") || lower.contains("key") {
                *value = "REDACTED".to_string();
            }
        }
    }
    redacted
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_export_import_round_trip() {
        let server = MCPServer::stdio("npx".into(), Some(vec!["-y".into(), "pkg".into()]), None);
        let json = export_to_json(&[("github", &server)], false);
        let imported = import_from_json(&json).unwrap();
        assert_eq!(imported.len(), 1);
        assert_eq!(imported[0].0, "github");
        assert_eq!(imported[0].1.command, Some("npx".to_string()));
    }

    #[test]
    fn test_redact_sensitive() {
        let mut env = HashMap::new();
        env.insert("GITHUB_TOKEN".to_string(), "secret123".to_string());
        env.insert("PATH".to_string(), "/usr/bin".to_string());
        let server = MCPServer::stdio("npx".into(), None, Some(env));

        let json = export_to_json(&[("github", &server)], true);
        assert!(json.contains("REDACTED"));
        assert!(!json.contains("secret123"));
        assert!(json.contains("/usr/bin"));
    }

    #[test]
    fn test_redact_preserves_non_sensitive() {
        let mut env = HashMap::new();
        env.insert("DEBUG".to_string(), "true".to_string());
        env.insert("LOG_LEVEL".to_string(), "info".to_string());
        let server = MCPServer::stdio("node".into(), None, Some(env));

        let redacted = redact_server(&server);
        let env = redacted.env.unwrap();
        assert_eq!(env.get("DEBUG"), Some(&"true".to_string()));
        assert_eq!(env.get("LOG_LEVEL"), Some(&"info".to_string()));
    }

    #[test]
    fn test_import_invalid_json() {
        let result = import_from_json("not valid json");
        assert!(result.is_err());
    }

    #[test]
    fn test_export_multiple() {
        let s1 = MCPServer::stdio("npx".into(), None, None);
        let s2 = MCPServer::http("https://example.com".into(), None);
        let json = export_to_json(&[("github", &s1), ("remote", &s2)], false);
        let imported = import_from_json(&json).unwrap();
        assert_eq!(imported.len(), 2);
    }

    #[test]
    fn test_redact_headers() {
        let mut headers = HashMap::new();
        headers.insert("Authorization".to_string(), "Bearer secret".to_string());
        headers.insert("Content-Type".to_string(), "application/json".to_string());
        let server = MCPServer::http("https://example.com".into(), Some(headers));

        let redacted = redact_server(&server);
        let headers = redacted.headers.unwrap();
        assert_eq!(headers.get("Authorization"), Some(&"REDACTED".to_string()));
        assert_eq!(
            headers.get("Content-Type"),
            Some(&"application/json".to_string())
        );
    }
}
