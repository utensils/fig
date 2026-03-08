use crate::models::{MCPConfig, MCPServer};

#[derive(Debug, Clone, PartialEq)]
pub struct CopyConflict {
    pub server_name: String,
    pub existing_summary: String,
}

#[derive(Debug, Clone, PartialEq)]
pub enum CopyResult {
    Success { copied_count: usize },
    Conflicts(Vec<CopyConflict>),
}

fn server_summary(server: &MCPServer) -> String {
    if server.is_http() {
        format!("http: {}", server.url.as_deref().unwrap_or("(no url)"))
    } else {
        format!(
            "stdio: {}",
            server.command.as_deref().unwrap_or("(no command)")
        )
    }
}

pub fn check_conflicts(names: &[&str], target: &MCPConfig) -> Vec<CopyConflict> {
    names
        .iter()
        .filter_map(|name| {
            target.server(name).map(|server| CopyConflict {
                server_name: name.to_string(),
                existing_summary: server_summary(server),
            })
        })
        .collect()
}

pub fn copy_servers(names: &[&str], from: &MCPConfig, to: &mut MCPConfig) -> CopyResult {
    let conflicts = check_conflicts(names, to);
    if !conflicts.is_empty() {
        return CopyResult::Conflicts(conflicts);
    }

    let mut copied = 0;
    let target_servers = to.mcp_servers.get_or_insert_with(Default::default);
    for name in names {
        if let Some(server) = from.server(name) {
            target_servers.insert(name.to_string(), server.clone());
            copied += 1;
        }
    }

    CopyResult::Success {
        copied_count: copied,
    }
}

pub fn force_copy_servers(names: &[&str], from: &MCPConfig, to: &mut MCPConfig) {
    let target_servers = to.mcp_servers.get_or_insert_with(Default::default);
    for name in names {
        if let Some(server) = from.server(name) {
            target_servers.insert(name.to_string(), server.clone());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn make_config(servers: Vec<(&str, MCPServer)>) -> MCPConfig {
        let mut map = HashMap::new();
        for (name, server) in servers {
            map.insert(name.to_string(), server);
        }
        MCPConfig {
            mcp_servers: Some(map),
            additional_properties: HashMap::new(),
        }
    }

    #[test]
    fn test_copy_no_conflict() {
        let from = make_config(vec![("github", MCPServer::stdio("npx".into(), None, None))]);
        let mut to = MCPConfig::default();

        let result = copy_servers(&["github"], &from, &mut to);
        assert_eq!(result, CopyResult::Success { copied_count: 1 });
        assert!(to.server("github").is_some());
    }

    #[test]
    fn test_copy_with_conflict() {
        let from = make_config(vec![("github", MCPServer::stdio("npx".into(), None, None))]);
        let mut to = make_config(vec![(
            "github",
            MCPServer::stdio("node".into(), None, None),
        )]);

        let result = copy_servers(&["github"], &from, &mut to);
        assert!(matches!(result, CopyResult::Conflicts(_)));
        if let CopyResult::Conflicts(conflicts) = result {
            assert_eq!(conflicts.len(), 1);
            assert_eq!(conflicts[0].server_name, "github");
            assert!(conflicts[0].existing_summary.contains("stdio: node"));
        }
    }

    #[test]
    fn test_force_copy() {
        let from = make_config(vec![("github", MCPServer::stdio("npx".into(), None, None))]);
        let mut to = make_config(vec![(
            "github",
            MCPServer::stdio("node".into(), None, None),
        )]);

        force_copy_servers(&["github"], &from, &mut to);
        assert_eq!(
            to.server("github").unwrap().command,
            Some("npx".to_string())
        );
    }

    #[test]
    fn test_copy_all_mixed() {
        let from = make_config(vec![
            ("github", MCPServer::stdio("npx".into(), None, None)),
            (
                "remote",
                MCPServer::http("https://example.com".into(), None),
            ),
        ]);
        let mut to = make_config(vec![(
            "github",
            MCPServer::stdio("node".into(), None, None),
        )]);

        let result = copy_servers(&["github", "remote"], &from, &mut to);
        assert!(matches!(result, CopyResult::Conflicts(_)));

        // Force copy both
        force_copy_servers(&["github", "remote"], &from, &mut to);
        assert_eq!(to.server_count(), 2);
        assert_eq!(
            to.server("github").unwrap().command,
            Some("npx".to_string())
        );
        assert!(to.server("remote").unwrap().is_http());
    }

    #[test]
    fn test_check_conflicts_empty_target() {
        let target = MCPConfig::default();
        let conflicts = check_conflicts(&["github", "remote"], &target);
        assert!(conflicts.is_empty());
    }

    #[test]
    fn test_server_summary_formatting() {
        let stdio = MCPServer::stdio("npx".into(), None, None);
        assert_eq!(server_summary(&stdio), "stdio: npx");

        let http = MCPServer::http("https://api.example.com".into(), None);
        assert_eq!(server_summary(&http), "http: https://api.example.com");
    }
}
