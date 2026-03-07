use std::collections::HashMap;
use std::fmt;

use super::mcp_server::MCPServer;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MCPServerType {
    Stdio,
    Sse,
}

impl fmt::Display for MCPServerType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Stdio => write!(f, "stdio"),
            Self::Sse => write!(f, "SSE/HTTP"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidationError {
    pub field: String,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct MCPServerFormData {
    pub name: String,
    pub command: String,
    pub args_text: String,
    pub env_text: String,
    pub url: String,
    pub server_type: MCPServerType,
    pub is_editing: bool,
    pub original_name: Option<String>,
}

impl MCPServerFormData {
    pub fn new() -> Self {
        Self {
            name: String::new(),
            command: String::new(),
            args_text: String::new(),
            env_text: String::new(),
            url: String::new(),
            server_type: MCPServerType::Stdio,
            is_editing: false,
            original_name: None,
        }
    }

    pub fn from_mcp_server(name: &str, server: &MCPServer) -> Self {
        let server_type = if server.is_http() {
            MCPServerType::Sse
        } else {
            MCPServerType::Stdio
        };

        let args_text = server
            .args
            .as_ref()
            .map(|args| args.join("\n"))
            .unwrap_or_default();

        let env_text = server
            .env
            .as_ref()
            .map(|env| {
                let mut pairs: Vec<_> = env.iter().collect();
                pairs.sort_by_key(|(k, _)| (*k).clone());
                pairs
                    .iter()
                    .map(|(k, v)| format!("{k}={v}"))
                    .collect::<Vec<_>>()
                    .join("\n")
            })
            .unwrap_or_default();

        Self {
            name: name.to_string(),
            command: server.command.clone().unwrap_or_default(),
            args_text,
            env_text,
            url: server.url.clone().unwrap_or_default(),
            server_type,
            is_editing: true,
            original_name: Some(name.to_string()),
        }
    }

    pub fn to_mcp_server(&self) -> MCPServer {
        match self.server_type {
            MCPServerType::Stdio => {
                let args: Vec<String> = self
                    .args_text
                    .lines()
                    .map(|l| l.trim().to_string())
                    .filter(|l| !l.is_empty())
                    .collect();
                let env = Self::parse_env_text(&self.env_text);

                MCPServer::stdio(
                    self.command.clone(),
                    if args.is_empty() { None } else { Some(args) },
                    if env.is_empty() { None } else { Some(env) },
                )
            }
            MCPServerType::Sse => MCPServer::http(self.url.clone(), None),
        }
    }

    pub fn validate(&self) -> Vec<ValidationError> {
        let mut errors = Vec::new();

        if self.name.trim().is_empty() {
            errors.push(ValidationError {
                field: "name".to_string(),
                message: "Server name is required.".to_string(),
            });
        }

        match self.server_type {
            MCPServerType::Stdio => {
                if self.command.trim().is_empty() {
                    errors.push(ValidationError {
                        field: "command".to_string(),
                        message: "Command is required for stdio servers.".to_string(),
                    });
                }
            }
            MCPServerType::Sse => {
                if self.url.trim().is_empty() {
                    errors.push(ValidationError {
                        field: "url".to_string(),
                        message: "URL is required for SSE/HTTP servers.".to_string(),
                    });
                }
            }
        }

        errors
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_empty()
    }

    fn parse_env_text(text: &str) -> HashMap<String, String> {
        let mut env = HashMap::new();
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            if let Some((key, value)) = trimmed.split_once('=') {
                let key = key.trim().to_string();
                if !key.is_empty() {
                    env.insert(key, value.trim().to_string());
                }
            }
        }
        env
    }
}

impl Default for MCPServerFormData {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_defaults() {
        let form = MCPServerFormData::new();
        assert!(form.name.is_empty());
        assert_eq!(form.server_type, MCPServerType::Stdio);
        assert!(!form.is_editing);
        assert!(form.original_name.is_none());
    }

    #[test]
    fn test_from_stdio_server() {
        let mut env = HashMap::new();
        env.insert("GITHUB_TOKEN".to_string(), "abc123".to_string());
        let server = MCPServer::stdio(
            "npx".to_string(),
            Some(vec!["-y".to_string(), "server-github".to_string()]),
            Some(env),
        );

        let form = MCPServerFormData::from_mcp_server("github", &server);
        assert_eq!(form.name, "github");
        assert_eq!(form.command, "npx");
        assert_eq!(form.server_type, MCPServerType::Stdio);
        assert!(form.args_text.contains("-y"));
        assert!(form.args_text.contains("server-github"));
        assert!(form.env_text.contains("GITHUB_TOKEN=abc123"));
        assert!(form.is_editing);
        assert_eq!(form.original_name, Some("github".to_string()));
    }

    #[test]
    fn test_from_http_server() {
        let server = MCPServer::http("https://mcp.example.com".to_string(), None);
        let form = MCPServerFormData::from_mcp_server("remote", &server);
        assert_eq!(form.server_type, MCPServerType::Sse);
        assert_eq!(form.url, "https://mcp.example.com");
        assert!(form.command.is_empty());
    }

    #[test]
    fn test_to_mcp_server_stdio() {
        let form = MCPServerFormData {
            name: "test".to_string(),
            command: "node".to_string(),
            args_text: "server.js\n--port\n3000".to_string(),
            env_text: "API_KEY=secret\nDEBUG=true".to_string(),
            url: String::new(),
            server_type: MCPServerType::Stdio,
            is_editing: false,
            original_name: None,
        };

        let server = form.to_mcp_server();
        assert!(server.is_stdio());
        assert_eq!(server.command, Some("node".to_string()));
        assert_eq!(
            server.args,
            Some(vec![
                "server.js".to_string(),
                "--port".to_string(),
                "3000".to_string()
            ])
        );
        let env = server.env.unwrap();
        assert_eq!(env.get("API_KEY"), Some(&"secret".to_string()));
        assert_eq!(env.get("DEBUG"), Some(&"true".to_string()));
    }

    #[test]
    fn test_to_mcp_server_sse() {
        let form = MCPServerFormData {
            name: "remote".to_string(),
            command: String::new(),
            args_text: String::new(),
            env_text: String::new(),
            url: "https://api.example.com".to_string(),
            server_type: MCPServerType::Sse,
            is_editing: false,
            original_name: None,
        };

        let server = form.to_mcp_server();
        assert!(server.is_http());
        assert_eq!(server.url, Some("https://api.example.com".to_string()));
    }

    #[test]
    fn test_round_trip() {
        let mut env = HashMap::new();
        env.insert("TOKEN".to_string(), "xyz".to_string());
        let original = MCPServer::stdio(
            "npx".to_string(),
            Some(vec!["-y".to_string(), "pkg".to_string()]),
            Some(env),
        );

        let form = MCPServerFormData::from_mcp_server("test", &original);
        let result = form.to_mcp_server();

        assert_eq!(original.command, result.command);
        assert_eq!(original.args, result.args);
        assert_eq!(original.env, result.env);
    }

    #[test]
    fn test_validate_empty_name() {
        let form = MCPServerFormData {
            name: "  ".to_string(),
            command: "node".to_string(),
            ..MCPServerFormData::new()
        };
        let errors = form.validate();
        assert!(errors.iter().any(|e| e.field == "name"));
    }

    #[test]
    fn test_validate_stdio_no_command() {
        let form = MCPServerFormData {
            name: "test".to_string(),
            command: "".to_string(),
            server_type: MCPServerType::Stdio,
            ..MCPServerFormData::new()
        };
        let errors = form.validate();
        assert!(errors.iter().any(|e| e.field == "command"));
        assert!(!form.is_valid());
    }

    #[test]
    fn test_validate_sse_no_url() {
        let form = MCPServerFormData {
            name: "test".to_string(),
            url: "".to_string(),
            server_type: MCPServerType::Sse,
            ..MCPServerFormData::new()
        };
        let errors = form.validate();
        assert!(errors.iter().any(|e| e.field == "url"));
    }

    #[test]
    fn test_validate_valid() {
        let form = MCPServerFormData {
            name: "github".to_string(),
            command: "npx".to_string(),
            server_type: MCPServerType::Stdio,
            ..MCPServerFormData::new()
        };
        assert!(form.is_valid());
    }

    #[test]
    fn test_env_text_parsing() {
        let env = MCPServerFormData::parse_env_text("KEY=value\n\nFOO = bar\ninvalid_line\n");
        assert_eq!(env.get("KEY"), Some(&"value".to_string()));
        assert_eq!(env.get("FOO"), Some(&"bar".to_string()));
        assert_eq!(env.len(), 2);
    }

    #[test]
    fn test_server_type_display() {
        assert_eq!(format!("{}", MCPServerType::Stdio), "stdio");
        assert_eq!(format!("{}", MCPServerType::Sse), "SSE/HTTP");
    }
}
