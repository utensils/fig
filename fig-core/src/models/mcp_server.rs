use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct MCPServer {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub args: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env: Option<HashMap<String, String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[serde(rename = "type")]
    pub server_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub headers: Option<HashMap<String, String>>,
    #[serde(flatten)]
    pub additional_properties: HashMap<String, Value>,
}

impl MCPServer {
    pub fn is_stdio(&self) -> bool {
        self.command.is_some() && self.server_type.as_deref() != Some("http")
    }

    pub fn is_http(&self) -> bool {
        self.server_type.as_deref() == Some("http") && self.url.is_some()
    }

    pub fn stdio(
        command: String,
        args: Option<Vec<String>>,
        env: Option<HashMap<String, String>>,
    ) -> Self {
        Self {
            command: Some(command),
            args,
            env,
            ..Default::default()
        }
    }

    pub fn http(url: String, headers: Option<HashMap<String, String>>) -> Self {
        Self {
            server_type: Some("http".to_string()),
            url: Some(url),
            headers,
            ..Default::default()
        }
    }

    pub fn has_sensitive_env(&self) -> bool {
        self.env
            .as_ref()
            .map(|e| {
                e.keys().any(|k| {
                    let lower = k.to_lowercase();
                    lower.contains("token")
                        || lower.contains("key")
                        || lower.contains("secret")
                        || lower.contains("password")
                })
            })
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stdio_server_round_trip() {
        let json = r#"{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_TOKEN":"test-token"},"customOption":true}"#;
        let parsed: MCPServer = serde_json::from_str(json).unwrap();
        assert_eq!(parsed.command, Some("npx".to_string()));
        assert!(parsed.is_stdio());
        assert!(!parsed.is_http());
        assert_eq!(
            parsed.additional_properties.get("customOption"),
            Some(&Value::Bool(true))
        );

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: MCPServer = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_http_server_round_trip() {
        let json = r#"{"type":"http","url":"https://mcp.example.com/api","headers":{"Authorization":"Bearer token"}}"#;
        let parsed: MCPServer = serde_json::from_str(json).unwrap();
        assert!(parsed.is_http());
        assert!(!parsed.is_stdio());

        let re_serialized = serde_json::to_string(&parsed).unwrap();
        let re_parsed: MCPServer = serde_json::from_str(&re_serialized).unwrap();
        assert_eq!(parsed, re_parsed);
    }

    #[test]
    fn test_mcp_server_factory_methods() {
        let stdio = MCPServer::stdio(
            "node".to_string(),
            Some(vec!["server.js".to_string()]),
            None,
        );
        assert!(stdio.is_stdio());
        assert_eq!(stdio.command, Some("node".to_string()));

        let http = MCPServer::http("https://api.example.com".to_string(), None);
        assert!(http.is_http());
        assert_eq!(http.url, Some("https://api.example.com".to_string()));
    }

    #[test]
    fn test_has_sensitive_env() {
        let mut env = HashMap::new();
        env.insert("GITHUB_TOKEN".to_string(), "secret".to_string());
        let server = MCPServer::stdio("cmd".to_string(), None, Some(env));
        assert!(server.has_sensitive_env());

        let server_no_env = MCPServer::stdio("cmd".to_string(), None, None);
        assert!(!server_no_env.has_sensitive_env());

        let mut safe_env = HashMap::new();
        safe_env.insert("PATH".to_string(), "/usr/bin".to_string());
        let server_safe = MCPServer::stdio("cmd".to_string(), None, Some(safe_env));
        assert!(!server_safe.has_sensitive_env());
    }
}
