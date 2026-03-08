use std::time::{Duration, Instant};

use crate::models::MCPServer;

#[derive(Debug, Clone, PartialEq)]
pub enum MCPHealthStatus {
    Success { server_info: String },
    Failure { error: String },
    Timeout,
}

#[derive(Debug, Clone)]
pub struct MCPHealthCheckResult {
    pub server_name: String,
    pub status: MCPHealthStatus,
    pub duration: Duration,
}

const HEALTH_CHECK_TIMEOUT_SECS: u64 = 10;

pub fn build_initialize_request() -> serde_json::Value {
    serde_json::json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "fig-health-check",
                "version": "1.0.0"
            }
        }
    })
}

pub async fn check_health(name: &str, server: &MCPServer) -> MCPHealthCheckResult {
    if server.is_http() {
        check_http(name, server).await
    } else if server.is_stdio() {
        check_stdio(name, server).await
    } else {
        MCPHealthCheckResult {
            server_name: name.to_string(),
            status: MCPHealthStatus::Failure {
                error: "Server has no command or URL configured.".to_string(),
            },
            duration: Duration::ZERO,
        }
    }
}

async fn check_stdio(name: &str, server: &MCPServer) -> MCPHealthCheckResult {
    let start = Instant::now();
    let command = match &server.command {
        Some(cmd) => cmd.clone(),
        None => {
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: "No command configured.".to_string(),
                },
                duration: start.elapsed(),
            };
        }
    };

    let args = server.args.clone().unwrap_or_default();
    let mut cmd = tokio::process::Command::new(&command);
    cmd.args(&args)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null());

    if let Some(ref env) = server.env {
        for (key, value) in env {
            cmd.env(key, value);
        }
    }

    let mut child = match cmd.spawn() {
        Ok(child) => child,
        Err(e) => {
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: format!("Failed to spawn process: {e}"),
                },
                duration: start.elapsed(),
            };
        }
    };

    let request = build_initialize_request();
    let request_body = match serde_json::to_string(&request) {
        Ok(body) => body,
        Err(e) => {
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: format!("Failed to serialize request: {e}"),
                },
                duration: start.elapsed(),
            };
        }
    };
    let message = format!(
        "Content-Length: {}\r\n\r\n{}",
        request_body.len(),
        request_body
    );

    // Write to stdin
    if let Some(ref mut stdin) = child.stdin {
        use tokio::io::AsyncWriteExt;
        if let Err(e) = stdin.write_all(message.as_bytes()).await {
            let _ = child.kill().await;
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: format!("Failed to write to stdin: {e}"),
                },
                duration: start.elapsed(),
            };
        }
    }

    // Read response with timeout
    let timeout = Duration::from_secs(HEALTH_CHECK_TIMEOUT_SECS);
    let read_result = tokio::time::timeout(timeout, async {
        if let Some(ref mut stdout) = child.stdout {
            use tokio::io::AsyncReadExt;
            let mut buf = vec![0u8; 4096];
            match stdout.read(&mut buf).await {
                Ok(n) if n > 0 => {
                    let response = String::from_utf8_lossy(&buf[..n]).to_string();
                    Ok(response)
                }
                Ok(_) => Err("Empty response from server".to_string()),
                Err(e) => Err(format!("Failed to read stdout: {e}")),
            }
        } else {
            Err("No stdout available".to_string())
        }
    })
    .await;

    let _ = child.kill().await;

    let status = match read_result {
        Ok(Ok(response)) => {
            if response.contains("\"result\"") || response.contains("initialize") {
                MCPHealthStatus::Success {
                    server_info: extract_server_info(&response),
                }
            } else {
                MCPHealthStatus::Failure {
                    error: "Invalid MCP handshake response.".to_string(),
                }
            }
        }
        Ok(Err(e)) => MCPHealthStatus::Failure { error: e },
        Err(_) => MCPHealthStatus::Timeout,
    };

    MCPHealthCheckResult {
        server_name: name.to_string(),
        status,
        duration: start.elapsed(),
    }
}

async fn check_http(name: &str, server: &MCPServer) -> MCPHealthCheckResult {
    let start = Instant::now();
    let url = match &server.url {
        Some(url) => url.clone(),
        None => {
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: "No URL configured.".to_string(),
                },
                duration: start.elapsed(),
            };
        }
    };

    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(HEALTH_CHECK_TIMEOUT_SECS))
        .build()
    {
        Ok(client) => client,
        Err(e) => {
            return MCPHealthCheckResult {
                server_name: name.to_string(),
                status: MCPHealthStatus::Failure {
                    error: format!("Failed to build HTTP client: {e}"),
                },
                duration: start.elapsed(),
            };
        }
    };

    let request = build_initialize_request();
    let mut req = client.post(&url).json(&request);

    if let Some(ref headers) = server.headers {
        for (key, value) in headers {
            req = req.header(key, value);
        }
    }

    let status = match req.send().await {
        Ok(resp) => {
            if resp.status().is_success() {
                match resp.text().await {
                    Ok(body) => MCPHealthStatus::Success {
                        server_info: extract_server_info(&body),
                    },
                    Err(e) => MCPHealthStatus::Failure {
                        error: format!("Failed to read response: {e}"),
                    },
                }
            } else {
                MCPHealthStatus::Failure {
                    error: format!("HTTP {}", resp.status()),
                }
            }
        }
        Err(e) => {
            if e.is_timeout() {
                MCPHealthStatus::Timeout
            } else {
                MCPHealthStatus::Failure {
                    error: format!("Request failed: {e}"),
                }
            }
        }
    };

    MCPHealthCheckResult {
        server_name: name.to_string(),
        status,
        duration: start.elapsed(),
    }
}

fn extract_server_info(response: &str) -> String {
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(response) {
        if let Some(info) = json
            .get("result")
            .and_then(|r| r.get("serverInfo"))
            .and_then(|s| s.get("name"))
            .and_then(|n| n.as_str())
        {
            return info.to_string();
        }
    }
    // Try to find serverInfo in Content-Length framed response
    if let Some(start) = response.find('{') {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&response[start..]) {
            if let Some(info) = json
                .get("result")
                .and_then(|r| r.get("serverInfo"))
                .and_then(|s| s.get("name"))
                .and_then(|n| n.as_str())
            {
                return info.to_string();
            }
        }
    }
    "MCP Server".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initialize_request_format() {
        let req = build_initialize_request();
        assert_eq!(req["jsonrpc"], "2.0");
        assert_eq!(req["method"], "initialize");
        assert!(req["params"]["protocolVersion"].is_string());
        assert!(req["params"]["clientInfo"]["name"].is_string());
    }

    #[test]
    fn test_extract_server_info_valid() {
        let response = r#"{"jsonrpc":"2.0","id":1,"result":{"serverInfo":{"name":"test-server","version":"1.0"}}}"#;
        assert_eq!(extract_server_info(response), "test-server");
    }

    #[test]
    fn test_extract_server_info_fallback() {
        let response = r#"{"jsonrpc":"2.0","id":1,"result":{}}"#;
        assert_eq!(extract_server_info(response), "MCP Server");
    }

    #[test]
    fn test_extract_server_info_with_content_length() {
        let response = "Content-Length: 80\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"serverInfo\":{\"name\":\"framed-server\"}}}";
        assert_eq!(extract_server_info(response), "framed-server");
    }

    #[tokio::test]
    async fn test_no_command_or_url() {
        let server = MCPServer::default();
        let result = check_health("test", &server).await;
        assert!(matches!(result.status, MCPHealthStatus::Failure { .. }));
    }
}
