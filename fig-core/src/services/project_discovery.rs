use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

use walkdir::WalkDir;

use crate::models::DiscoveredProject;
use crate::services::ConfigFileManager;

pub struct ProjectDiscoveryService {
    config_manager: ConfigFileManager,
}

const DEFAULT_SCAN_DIRECTORIES: &[&str] = &[
    "~",
    "~/code",
    "~/Code",
    "~/projects",
    "~/Projects",
    "~/Developer",
    "~/dev",
    "~/src",
    "~/repos",
    "~/github",
    "~/workspace",
];

const SKIP_DIRECTORIES: &[&str] = &[
    "node_modules",
    ".git",
    ".svn",
    ".hg",
    "vendor",
    "Pods",
    ".build",
    "build",
    "dist",
    "target",
    "__pycache__",
    ".venv",
    "venv",
    ".cache",
    "Library",
    "Applications",
];

impl ProjectDiscoveryService {
    pub fn new(config_manager: ConfigFileManager) -> Self {
        Self { config_manager }
    }

    pub fn discover_projects(
        &self,
        scan_directories: bool,
        directories: Option<&[String]>,
    ) -> Vec<DiscoveredProject> {
        let mut all_paths = HashSet::new();

        // 1. Discover from legacy config (fault-tolerant)
        if let Ok(paths) = self.discover_from_legacy_config() {
            all_paths.extend(paths);
        }

        // 2. Optionally scan directories
        if scan_directories {
            let scanned = match directories {
                Some(dirs) => self.scan_for_projects(dirs),
                None => {
                    let defaults: Vec<String> = DEFAULT_SCAN_DIRECTORIES
                        .iter()
                        .map(|s| s.to_string())
                        .collect();
                    self.scan_for_projects(&defaults)
                }
            };
            all_paths.extend(scanned);
        }

        // 3. Build discovered project entries
        let mut projects: Vec<DiscoveredProject> = all_paths
            .into_iter()
            .filter_map(|path| self.build_discovered_project(&path))
            .collect();

        // 4. Sort by last modified (most recent first), then by name
        projects.sort_by(|a, b| match (&a.last_modified, &b.last_modified) {
            (Some(t1), Some(t2)) => t2.cmp(t1),
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (Some(_), None) => std::cmp::Ordering::Less,
            (None, None) => a
                .display_name
                .to_lowercase()
                .cmp(&b.display_name.to_lowercase()),
        });

        projects
    }

    pub fn discover_from_legacy_config(
        &self,
    ) -> Result<Vec<PathBuf>, crate::error::ConfigFileError> {
        let config = self.config_manager.read_global_config()?;
        let Some(config) = config else {
            return Ok(vec![]);
        };

        Ok(config
            .project_paths()
            .into_iter()
            .filter_map(|p| self.canonicalize_path(p))
            .collect())
    }

    pub fn scan_for_projects(&self, directories: &[String]) -> Vec<PathBuf> {
        let mut discovered = HashSet::new();

        for dir in directories {
            let expanded = self.expand_path(dir);
            if let Some(canonical) = self.canonicalize_path(&expanded) {
                let paths = self.scan_directory(&canonical, 3);
                discovered.extend(paths);
            }
        }

        discovered.into_iter().collect()
    }

    pub fn refresh_project(&self, path: &Path) -> Option<DiscoveredProject> {
        self.build_discovered_project(path)
    }

    fn build_discovered_project(&self, path: &Path) -> Option<DiscoveredProject> {
        let canonical = self.canonicalize_path(path)?;
        let exists = canonical.exists();
        let display_name = canonical
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        let claude_dir = canonical.join(".claude");
        let has_settings = claude_dir.join("settings.json").is_file();
        let has_local_settings = claude_dir.join("settings.local.json").is_file();
        let has_mcp_config = canonical.join(".mcp.json").is_file();

        let last_modified = self.get_last_modified(&canonical);

        Some(DiscoveredProject::new(
            canonical,
            display_name,
            exists,
            has_settings,
            has_local_settings,
            has_mcp_config,
            last_modified,
        ))
    }

    fn scan_directory(&self, path: &Path, max_depth: usize) -> Vec<PathBuf> {
        let skip: HashSet<&str> = SKIP_DIRECTORIES.iter().copied().collect();
        let mut discovered = Vec::new();

        let walker = WalkDir::new(path)
            .max_depth(max_depth)
            .follow_links(false)
            .into_iter()
            .filter_entry(|entry| {
                let name = entry.file_name().to_str().unwrap_or("");
                // Allow the root entry, skip hidden dirs (except root) and known skip dirs
                if entry.depth() == 0 {
                    return true;
                }
                if name.starts_with('.') {
                    return false;
                }
                !skip.contains(name)
            });

        for entry in walker.flatten() {
            if entry.file_type().is_dir() {
                let entry_path = entry.path();
                if entry_path.join(".claude").is_dir() {
                    discovered.push(entry_path.to_path_buf());
                }
            }
        }

        discovered
    }

    fn expand_path(&self, path: &str) -> PathBuf {
        if let Some(rest) = path.strip_prefix('~') {
            if let Some(home) = dirs::home_dir() {
                return home.join(rest.trim_start_matches('/'));
            }
        }
        PathBuf::from(path)
    }

    fn canonicalize_path<P: AsRef<Path>>(&self, path: P) -> Option<PathBuf> {
        let expanded = if let Some(s) = path.as_ref().to_str() {
            self.expand_path(s)
        } else {
            path.as_ref().to_path_buf()
        };

        // Try to canonicalize, but fall back to the expanded path if it doesn't exist yet
        let result = fs::canonicalize(&expanded).unwrap_or(expanded);

        if result.is_absolute() {
            Some(result)
        } else {
            None
        }
    }

    fn get_last_modified(&self, path: &Path) -> Option<SystemTime> {
        let config_paths = [
            path.join(".claude/settings.local.json"),
            path.join(".claude/settings.json"),
            path.join(".mcp.json"),
        ];

        let mut most_recent: Option<SystemTime> = None;

        for config_path in &config_paths {
            if let Ok(metadata) = fs::metadata(config_path) {
                if let Ok(modified) = metadata.modified() {
                    if most_recent.map(|r| modified > r).unwrap_or(true) {
                        most_recent = Some(modified);
                    }
                }
            }
        }

        // Fall back to directory modification date
        if most_recent.is_none() {
            if let Ok(metadata) = fs::metadata(path) {
                most_recent = metadata.modified().ok();
            }
        }

        most_recent
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn setup_service(home: &Path) -> ProjectDiscoveryService {
        let config_manager = ConfigFileManager::with_home_dir(home.to_path_buf());
        ProjectDiscoveryService::new(config_manager)
    }

    #[test]
    fn test_discover_empty_config() {
        let tmp = TempDir::new().unwrap();
        let service = setup_service(tmp.path());
        let projects = service.discover_projects(false, None);
        assert!(projects.is_empty());
    }

    #[test]
    fn test_discover_from_legacy_config() {
        let tmp = TempDir::new().unwrap();

        // Create a project directory with .claude
        let project_dir = tmp.path().join("myproject");
        fs::create_dir_all(project_dir.join(".claude")).unwrap();

        // Write a legacy config pointing to the project
        let config_path = tmp.path().join(".claude.json");
        let config_json = format!(
            r#"{{"projects": {{"{path}": {{"allowedTools": []}}}}}}"#,
            path = project_dir.display()
        );
        fs::write(&config_path, config_json).unwrap();

        let service = setup_service(tmp.path());
        let paths = service.discover_from_legacy_config().unwrap();
        assert_eq!(paths.len(), 1);
    }

    #[test]
    fn test_scan_directory_finds_claude_projects() {
        let tmp = TempDir::new().unwrap();

        // Create two projects with .claude dirs
        let proj_a = tmp.path().join("proj_a");
        let proj_b = tmp.path().join("proj_b");
        let not_a_project = tmp.path().join("no_claude");
        fs::create_dir_all(proj_a.join(".claude")).unwrap();
        fs::create_dir_all(proj_b.join(".claude")).unwrap();
        fs::create_dir_all(&not_a_project).unwrap();

        let service = setup_service(tmp.path());
        let found = service.scan_directory(tmp.path(), 3);
        assert_eq!(found.len(), 2);
    }

    #[test]
    fn test_scan_skips_node_modules() {
        let tmp = TempDir::new().unwrap();

        let node_project = tmp.path().join("node_modules").join("pkg");
        fs::create_dir_all(node_project.join(".claude")).unwrap();

        let service = setup_service(tmp.path());
        let found = service.scan_directory(tmp.path(), 3);
        assert!(found.is_empty());
    }

    #[test]
    fn test_build_discovered_project() {
        let tmp = TempDir::new().unwrap();
        let project = tmp.path().join("myapp");
        fs::create_dir_all(project.join(".claude")).unwrap();
        fs::write(project.join(".claude").join("settings.json"), "{}").unwrap();
        fs::write(project.join(".mcp.json"), "{}").unwrap();

        let service = setup_service(tmp.path());
        let discovered = service.build_discovered_project(&project).unwrap();

        assert_eq!(discovered.display_name, "myapp");
        assert!(discovered.exists);
        assert!(discovered.has_settings);
        assert!(!discovered.has_local_settings);
        assert!(discovered.has_mcp_config);
        assert!(discovered.has_any_config());
    }

    #[test]
    fn test_refresh_project() {
        let tmp = TempDir::new().unwrap();
        let project = tmp.path().join("myapp");
        fs::create_dir_all(project.join(".claude")).unwrap();

        let service = setup_service(tmp.path());
        let discovered = service.refresh_project(&project);
        assert!(discovered.is_some());
        assert_eq!(discovered.unwrap().display_name, "myapp");
    }

    #[test]
    fn test_projects_sorted_by_modification_time() {
        let tmp = TempDir::new().unwrap();

        // Create two projects
        let old_proj = tmp.path().join("old_project");
        let new_proj = tmp.path().join("new_project");
        fs::create_dir_all(old_proj.join(".claude")).unwrap();
        fs::create_dir_all(new_proj.join(".claude")).unwrap();

        // Write config to new_project to give it a more recent modification time
        fs::write(new_proj.join(".claude").join("settings.json"), "{}").unwrap();

        let service = setup_service(tmp.path());
        let dirs = vec![tmp.path().to_string_lossy().to_string()];
        let projects = service.discover_projects(true, Some(&dirs));

        assert_eq!(projects.len(), 2);
        // new_project should come first (more recently modified)
        assert_eq!(projects[0].display_name, "new_project");
    }

    #[test]
    fn test_expand_path_tilde() {
        let tmp = TempDir::new().unwrap();
        let service = setup_service(tmp.path());

        let expanded = service.expand_path("~/code");
        assert!(expanded.is_absolute());
        assert!(expanded.to_string_lossy().ends_with("/code"));
    }

    #[test]
    fn test_expand_path_absolute() {
        let tmp = TempDir::new().unwrap();
        let service = setup_service(tmp.path());

        let expanded = service.expand_path("/usr/local");
        assert_eq!(expanded, PathBuf::from("/usr/local"));
    }
}
