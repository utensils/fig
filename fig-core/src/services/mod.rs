pub mod config_file_manager;
pub mod file_watcher;
pub mod project_discovery;
pub mod settings_merge;
pub mod undo_manager;

pub use config_file_manager::ConfigFileManager;
pub use file_watcher::{FileWatchEvent, FileWatchEventKind, FileWatcher};
pub use project_discovery::ProjectDiscoveryService;
pub use settings_merge::SettingsMergeService;
pub use undo_manager::UndoManager;
