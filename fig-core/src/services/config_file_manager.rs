use std::fs;
use std::path::{Path, PathBuf};

use chrono::Local;
use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::error::ConfigFileError;
use crate::models::{ClaudeSettings, LegacyConfig, MCPConfig};

pub struct ConfigFileManager {
    home_dir: PathBuf,
}

impl ConfigFileManager {
    pub fn new() -> Result<Self, ConfigFileError> {
        let home = dirs::home_dir().ok_or_else(|| ConfigFileError::FileNotFound {
            path: PathBuf::from("~"),
        })?;
        Ok(Self { home_dir: home })
    }

    pub fn with_home_dir(home: PathBuf) -> Self {
        Self { home_dir: home }
    }

    // Path resolution

    pub fn global_config_path(&self) -> PathBuf {
        self.home_dir.join(".claude.json")
    }

    pub fn global_settings_dir(&self) -> PathBuf {
        self.home_dir.join(".claude")
    }

    pub fn global_settings_path(&self) -> PathBuf {
        self.home_dir.join(".claude").join("settings.json")
    }

    pub fn project_settings_dir(&self, project: &Path) -> PathBuf {
        project.join(".claude")
    }

    pub fn project_settings_path(&self, project: &Path) -> PathBuf {
        project.join(".claude").join("settings.json")
    }

    pub fn project_local_settings_path(&self, project: &Path) -> PathBuf {
        project.join(".claude").join("settings.local.json")
    }

    pub fn mcp_config_path(&self, project: &Path) -> PathBuf {
        project.join(".mcp.json")
    }

    // Generic read/write

    pub fn read<T: DeserializeOwned>(&self, path: &Path) -> Result<Option<T>, ConfigFileError> {
        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(path).map_err(|e| {
            if e.kind() == std::io::ErrorKind::PermissionDenied {
                ConfigFileError::PermissionDenied {
                    path: path.to_path_buf(),
                }
            } else {
                ConfigFileError::ReadError {
                    path: path.to_path_buf(),
                    message: e.to_string(),
                }
            }
        })?;

        serde_json::from_str(&content)
            .map(Some)
            .map_err(|e| ConfigFileError::InvalidJson {
                path: path.to_path_buf(),
                message: e.to_string(),
            })
    }

    pub fn write<T: Serialize>(&self, value: &T, path: &Path) -> Result<(), ConfigFileError> {
        if path.exists() {
            self.create_backup(path)?;
        }

        let parent = path.parent().ok_or_else(|| ConfigFileError::WriteError {
            path: path.to_path_buf(),
            message: "No parent directory".to_string(),
        })?;

        fs::create_dir_all(parent).map_err(|e| ConfigFileError::WriteError {
            path: path.to_path_buf(),
            message: e.to_string(),
        })?;

        let content =
            serde_json::to_string_pretty(value).map_err(|e| ConfigFileError::WriteError {
                path: path.to_path_buf(),
                message: e.to_string(),
            })?;

        // Write to a temp file then rename for atomic operation
        let temp_path = parent.join(format!(".fig-tmp-{}", std::process::id()));
        fs::write(&temp_path, &content).map_err(|e| {
            let _ = fs::remove_file(&temp_path);
            ConfigFileError::WriteError {
                path: path.to_path_buf(),
                message: e.to_string(),
            }
        })?;

        fs::rename(&temp_path, path).map_err(|e| {
            let _ = fs::remove_file(&temp_path);
            ConfigFileError::WriteError {
                path: path.to_path_buf(),
                message: e.to_string(),
            }
        })
    }

    // Typed convenience methods

    pub fn read_global_config(&self) -> Result<Option<LegacyConfig>, ConfigFileError> {
        self.read(&self.global_config_path())
    }

    pub fn read_global_settings(&self) -> Result<Option<ClaudeSettings>, ConfigFileError> {
        self.read(&self.global_settings_path())
    }

    pub fn read_project_settings(
        &self,
        project: &Path,
    ) -> Result<Option<ClaudeSettings>, ConfigFileError> {
        self.read(&self.project_settings_path(project))
    }

    pub fn read_project_local_settings(
        &self,
        project: &Path,
    ) -> Result<Option<ClaudeSettings>, ConfigFileError> {
        self.read(&self.project_local_settings_path(project))
    }

    pub fn read_mcp_config(&self, project: &Path) -> Result<Option<MCPConfig>, ConfigFileError> {
        self.read(&self.mcp_config_path(project))
    }

    pub fn write_global_config(&self, config: &LegacyConfig) -> Result<(), ConfigFileError> {
        let path = self.global_config_path();
        self.write(config, &path)
    }

    pub fn write_global_settings(&self, settings: &ClaudeSettings) -> Result<(), ConfigFileError> {
        let path = self.global_settings_path();
        self.write(settings, &path)
    }

    pub fn write_project_settings(
        &self,
        project: &Path,
        settings: &ClaudeSettings,
    ) -> Result<(), ConfigFileError> {
        let path = self.project_settings_path(project);
        self.write(settings, &path)
    }

    pub fn write_project_local_settings(
        &self,
        project: &Path,
        settings: &ClaudeSettings,
    ) -> Result<(), ConfigFileError> {
        let path = self.project_local_settings_path(project);
        self.write(settings, &path)
    }

    pub fn write_mcp_config(
        &self,
        project: &Path,
        config: &MCPConfig,
    ) -> Result<(), ConfigFileError> {
        let path = self.mcp_config_path(project);
        self.write(config, &path)
    }

    // Backup

    fn create_backup(&self, path: &Path) -> Result<(), ConfigFileError> {
        let timestamp = Local::now().format("%Y-%m-%dT%H-%M-%S").to_string();
        let file_stem = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("backup");
        let extension = path.extension().and_then(|s| s.to_str()).unwrap_or("json");
        let backup_name = format!("{file_stem}.{timestamp}.{extension}");
        let backup_path = path.with_file_name(backup_name);

        fs::copy(path, &backup_path).map_err(|e| ConfigFileError::BackupFailed {
            path: path.to_path_buf(),
            message: e.to_string(),
        })?;
        Ok(())
    }

    // Utilities

    pub fn file_exists(&self, path: &Path) -> bool {
        path.exists()
    }

    pub fn delete(&self, path: &Path) -> Result<(), ConfigFileError> {
        if path.exists() {
            self.create_backup(path)?;
            fs::remove_file(path).map_err(|e| ConfigFileError::WriteError {
                path: path.to_path_buf(),
                message: e.to_string(),
            })?;
        }
        Ok(())
    }

    pub fn resolve_symlink(
        &self,
        path: &Path,
        max_depth: usize,
    ) -> Result<PathBuf, ConfigFileError> {
        let mut current = path.to_path_buf();
        for _ in 0..max_depth {
            if !current.is_symlink() {
                return Ok(current);
            }
            let parent = current.parent().unwrap_or(Path::new(".")).to_path_buf();
            let target = fs::read_link(&current).map_err(|_| ConfigFileError::CircularSymlink {
                path: path.to_path_buf(),
            })?;
            current = if target.is_relative() {
                parent.join(&target)
            } else {
                target
            };
        }
        Err(ConfigFileError::CircularSymlink {
            path: path.to_path_buf(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_read_missing_file_returns_none() {
        let tmp = TempDir::new().unwrap();
        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let result: Result<Option<ClaudeSettings>, _> =
            mgr.read(Path::new("/nonexistent/path.json"));
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_read_valid_json() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("settings.json");
        fs::write(&file_path, r#"{"permissions":{"allow":["Bash(*)"]}}"#).unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let result: Option<ClaudeSettings> = mgr.read(&file_path).unwrap();
        assert!(result.is_some());
        let settings = result.unwrap();
        assert_eq!(
            settings.permissions.unwrap().allow,
            Some(vec!["Bash(*)".to_string()])
        );
    }

    #[test]
    fn test_read_invalid_json() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("bad.json");
        fs::write(&file_path, "not valid json{{{").unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let result: Result<Option<ClaudeSettings>, _> = mgr.read(&file_path);
        assert!(matches!(result, Err(ConfigFileError::InvalidJson { .. })));
    }

    #[test]
    fn test_write_creates_backup() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("settings.json");
        fs::write(&file_path, "{}").unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let settings = ClaudeSettings::default();
        mgr.write(&settings, &file_path).unwrap();

        let entries: Vec<_> = fs::read_dir(tmp.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .unwrap_or("")
                    .starts_with("settings.")
            })
            .collect();
        assert!(entries.len() >= 2, "Expected backup file to be created");
    }

    #[test]
    fn test_write_creates_parent_dirs() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("deep").join("nested").join("settings.json");

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let settings = ClaudeSettings::default();
        mgr.write(&settings, &file_path).unwrap();

        assert!(file_path.exists());
    }

    #[test]
    fn test_write_pretty_json() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("settings.json");

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let settings = ClaudeSettings {
            disallowed_tools: Some(vec!["Tool".to_string()]),
            ..Default::default()
        };
        mgr.write(&settings, &file_path).unwrap();

        let content = fs::read_to_string(&file_path).unwrap();
        assert!(content.contains('\n'), "Expected pretty-printed JSON");
    }

    #[test]
    fn test_path_resolution() {
        let tmp = TempDir::new().unwrap();
        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());

        assert_eq!(mgr.global_config_path(), tmp.path().join(".claude.json"));
        assert_eq!(
            mgr.global_settings_path(),
            tmp.path().join(".claude").join("settings.json")
        );

        let project = Path::new("/my/project");
        assert_eq!(
            mgr.project_settings_path(project),
            Path::new("/my/project/.claude/settings.json")
        );
        assert_eq!(
            mgr.project_local_settings_path(project),
            Path::new("/my/project/.claude/settings.local.json")
        );
        assert_eq!(
            mgr.mcp_config_path(project),
            Path::new("/my/project/.mcp.json")
        );
    }

    #[cfg(unix)]
    #[test]
    fn test_symlink_resolution() {
        let tmp = TempDir::new().unwrap();
        let real_file = tmp.path().join("real.json");
        fs::write(&real_file, "{}").unwrap();

        let link_path = tmp.path().join("link.json");
        std::os::unix::fs::symlink(&real_file, &link_path).unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let resolved = mgr.resolve_symlink(&link_path, 10).unwrap();
        assert_eq!(resolved, real_file);
    }

    #[test]
    fn test_delete_creates_backup() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("to_delete.json");
        fs::write(&file_path, "{}").unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        mgr.delete(&file_path).unwrap();

        assert!(!file_path.exists());
        let entries: Vec<_> = fs::read_dir(tmp.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .unwrap_or("")
                    .starts_with("to_delete.")
            })
            .collect();
        assert!(!entries.is_empty(), "Expected backup file");
    }

    #[test]
    fn test_backup_timestamp_format() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("settings.json");
        fs::write(&file_path, "{}").unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        mgr.create_backup(&file_path).unwrap();

        let entries: Vec<_> = fs::read_dir(tmp.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .map(|e| e.file_name().to_string_lossy().to_string())
            .filter(|name| name != "settings.json")
            .collect();

        assert_eq!(entries.len(), 1);
        let backup_name = &entries[0];
        assert!(backup_name.starts_with("settings."));
        assert!(backup_name.ends_with(".json"));
        assert!(backup_name.contains('T'));
    }

    #[cfg(unix)]
    #[test]
    fn test_symlink_resolution_relative() {
        let tmp = TempDir::new().unwrap();
        let subdir = tmp.path().join("subdir");
        fs::create_dir(&subdir).unwrap();
        let real_file = subdir.join("real.json");
        fs::write(&real_file, "{}").unwrap();

        // Create a symlink in tmp root pointing to a relative path
        let link_path = tmp.path().join("link.json");
        std::os::unix::fs::symlink("subdir/real.json", &link_path).unwrap();

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let resolved = mgr.resolve_symlink(&link_path, 10).unwrap();
        assert!(resolved.ends_with("subdir/real.json"));
        assert!(!resolved.is_symlink());
    }

    #[test]
    fn test_write_atomic_no_temp_file_left() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("settings.json");

        let mgr = ConfigFileManager::with_home_dir(tmp.path().to_path_buf());
        let settings = ClaudeSettings::default();
        mgr.write(&settings, &file_path).unwrap();

        // Verify the file was written
        assert!(file_path.exists());

        // Verify no temp files remain
        let temp_files: Vec<_> = fs::read_dir(tmp.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .unwrap_or("")
                    .starts_with(".fig-tmp-")
            })
            .collect();
        assert!(temp_files.is_empty(), "Temp file should be cleaned up");
    }
}
