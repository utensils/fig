use std::path::{Path, PathBuf};
use std::time::SystemTime;

#[derive(Debug, Clone, PartialEq)]
pub struct DiscoveredProject {
    pub path: PathBuf,
    pub display_name: String,
    pub exists: bool,
    pub has_settings: bool,
    pub has_local_settings: bool,
    pub has_mcp_config: bool,
    pub last_modified: Option<SystemTime>,
}

impl DiscoveredProject {
    pub fn new(
        path: PathBuf,
        display_name: String,
        exists: bool,
        has_settings: bool,
        has_local_settings: bool,
        has_mcp_config: bool,
        last_modified: Option<SystemTime>,
    ) -> Self {
        Self {
            path,
            display_name,
            exists,
            has_settings,
            has_local_settings,
            has_mcp_config,
            last_modified,
        }
    }

    pub fn id(&self) -> &Path {
        &self.path
    }

    pub fn has_any_config(&self) -> bool {
        self.has_settings || self.has_local_settings || self.has_mcp_config
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_project() {
        let project = DiscoveredProject::new(
            PathBuf::from("/Users/sean/code/relay"),
            "relay".to_string(),
            true,
            true,
            false,
            true,
            None,
        );
        assert_eq!(project.display_name, "relay");
        assert!(project.exists);
        assert!(project.has_settings);
        assert!(!project.has_local_settings);
        assert!(project.has_mcp_config);
    }

    #[test]
    fn test_id_is_path() {
        let project = DiscoveredProject::new(
            PathBuf::from("/my/project"),
            "project".to_string(),
            true,
            false,
            false,
            false,
            None,
        );
        assert_eq!(project.id(), Path::new("/my/project"));
    }

    #[test]
    fn test_has_any_config() {
        let no_config = DiscoveredProject::new(
            PathBuf::from("/a"),
            "a".to_string(),
            true,
            false,
            false,
            false,
            None,
        );
        assert!(!no_config.has_any_config());

        let with_settings = DiscoveredProject::new(
            PathBuf::from("/b"),
            "b".to_string(),
            true,
            true,
            false,
            false,
            None,
        );
        assert!(with_settings.has_any_config());

        let with_local = DiscoveredProject::new(
            PathBuf::from("/c"),
            "c".to_string(),
            true,
            false,
            true,
            false,
            None,
        );
        assert!(with_local.has_any_config());

        let with_mcp = DiscoveredProject::new(
            PathBuf::from("/d"),
            "d".to_string(),
            true,
            false,
            false,
            true,
            None,
        );
        assert!(with_mcp.has_any_config());
    }

    #[test]
    fn test_equality() {
        let a = DiscoveredProject::new(
            PathBuf::from("/a"),
            "a".to_string(),
            true,
            false,
            false,
            false,
            None,
        );
        let b = DiscoveredProject::new(
            PathBuf::from("/a"),
            "a".to_string(),
            true,
            false,
            false,
            false,
            None,
        );
        assert_eq!(a, b);
    }
}
