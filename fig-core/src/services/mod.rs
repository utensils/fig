pub mod config_file_manager;
pub mod file_watcher;
pub mod health_check;
pub mod mcp_clipboard_service;
pub mod mcp_copy_service;
pub mod mcp_health_check;
pub mod project_discovery;
pub mod settings_merge;
pub mod undo_manager;

pub use config_file_manager::ConfigFileManager;
pub use file_watcher::{FileWatchEvent, FileWatchEventKind, FileWatcher};
pub use health_check::{Finding, FindingSeverity, HealthCheckContext};
pub use mcp_clipboard_service::ShareableServerConfig;
pub use mcp_copy_service::{CopyConflict, CopyResult};
pub use mcp_health_check::{MCPHealthCheckResult, MCPHealthStatus};
pub use project_discovery::ProjectDiscoveryService;
pub use settings_merge::SettingsMergeService;
pub use undo_manager::UndoManager;
