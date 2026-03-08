use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use tokio::sync::mpsc;

#[derive(Debug, Clone)]
pub struct FileWatchEvent {
    pub path: PathBuf,
    pub kind: FileWatchEventKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileWatchEventKind {
    Modified,
    Deleted,
    Created,
}

pub struct FileWatcher {
    watcher: RecommendedWatcher,
    /// Maps user-provided path to the effective path passed to the OS watcher.
    watched_paths: HashMap<PathBuf, PathBuf>,
    _tx: mpsc::UnboundedSender<FileWatchEvent>,
}

impl FileWatcher {
    pub fn new() -> Result<(Self, mpsc::UnboundedReceiver<FileWatchEvent>), notify::Error> {
        let (tx, rx) = mpsc::unbounded_channel();
        let tx_clone = tx.clone();

        let watcher = notify::recommended_watcher(move |res: Result<Event, notify::Error>| {
            if let Ok(event) = res {
                let kind = match event.kind {
                    EventKind::Create(_) => Some(FileWatchEventKind::Created),
                    EventKind::Modify(_) => Some(FileWatchEventKind::Modified),
                    EventKind::Remove(_) => Some(FileWatchEventKind::Deleted),
                    _ => None,
                };

                if let Some(kind) = kind {
                    for path in event.paths {
                        let _ = tx_clone.send(FileWatchEvent { path, kind });
                    }
                }
            }
        })?;

        Ok((
            Self {
                watcher,
                watched_paths: HashMap::new(),
                _tx: tx,
            },
            rx,
        ))
    }

    pub fn watch(&mut self, path: &Path) -> Result<(), notify::Error> {
        let watch_path = if path.is_file() {
            path.parent().unwrap_or(path).to_path_buf()
        } else {
            path.to_path_buf()
        };

        self.watcher
            .watch(&watch_path, RecursiveMode::NonRecursive)?;
        self.watched_paths.insert(path.to_path_buf(), watch_path);
        Ok(())
    }

    pub fn unwatch(&mut self, path: &Path) -> Result<(), notify::Error> {
        if let Some(watch_path) = self.watched_paths.remove(path) {
            self.watcher.unwatch(&watch_path)?;
        }
        Ok(())
    }

    pub fn unwatch_all(&mut self) {
        let entries: Vec<(PathBuf, PathBuf)> = self.watched_paths.drain().collect();
        for (_path, watch_path) in entries {
            let _ = self.watcher.unwatch(&watch_path);
        }
    }

    pub fn is_watching(&self, path: &Path) -> bool {
        self.watched_paths.contains_key(path)
    }
}

impl Drop for FileWatcher {
    fn drop(&mut self) {
        self.unwatch_all();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_watch_file_modification() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("test.json");
        fs::write(&file_path, "{}").unwrap();

        let (mut watcher, mut rx) = FileWatcher::new().unwrap();
        watcher.watch(&file_path).unwrap();

        fs::write(&file_path, r#"{"changed": true}"#).unwrap();

        let event = tokio::time::timeout(std::time::Duration::from_secs(5), rx.recv()).await;

        assert!(event.is_ok(), "Should receive event within timeout");
        let event = event.unwrap().unwrap();
        assert!(matches!(
            event.kind,
            FileWatchEventKind::Modified | FileWatchEventKind::Created
        ));
    }

    #[test]
    fn test_is_watching() {
        let tmp = TempDir::new().unwrap();
        let file_path = tmp.path().join("test.json");
        fs::write(&file_path, "{}").unwrap();

        let (mut watcher, _rx) = FileWatcher::new().unwrap();
        assert!(!watcher.is_watching(&file_path));

        watcher.watch(&file_path).unwrap();
        assert!(watcher.is_watching(&file_path));

        watcher.unwatch(&file_path).unwrap();
        assert!(!watcher.is_watching(&file_path));
    }

    #[test]
    fn test_unwatch_all() {
        let tmp = TempDir::new().unwrap();
        let file1 = tmp.path().join("a.json");
        let file2 = tmp.path().join("b.json");
        fs::write(&file1, "{}").unwrap();
        fs::write(&file2, "{}").unwrap();

        let (mut watcher, _rx) = FileWatcher::new().unwrap();
        watcher.watch(&file1).unwrap();
        watcher.watch(&file2).unwrap();
        assert!(watcher.is_watching(&file1));
        assert!(watcher.is_watching(&file2));

        watcher.unwatch_all();
        assert!(!watcher.is_watching(&file1));
        assert!(!watcher.is_watching(&file2));
    }
}
