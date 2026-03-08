use std::path::PathBuf;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum FigError {
    #[error("Configuration error: {0}")]
    Config(#[from] ConfigFileError),

    #[error("Health check error: {0}")]
    HealthCheck(String),

    #[error("MCP error: {0}")]
    Mcp(String),

    #[error("Bundle error: {0}")]
    Bundle(#[from] ConfigBundleError),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("{0}")]
    Other(String),
}

#[derive(Debug, Error)]
pub enum ConfigFileError {
    #[error("File not found: {path}")]
    FileNotFound { path: PathBuf },

    #[error("Permission denied: {path}")]
    PermissionDenied { path: PathBuf },

    #[error("Failed to read {path}: {message}")]
    ReadError { path: PathBuf, message: String },

    #[error("Invalid JSON in {path}: {message}")]
    InvalidJson { path: PathBuf, message: String },

    #[error("Failed to write {path}: {message}")]
    WriteError { path: PathBuf, message: String },

    #[error("Backup failed for {path}: {message}")]
    BackupFailed { path: PathBuf, message: String },

    #[error("Circular symlink detected at {path}")]
    CircularSymlink { path: PathBuf },
}

impl ConfigFileError {
    pub fn recovery_suggestion(&self) -> &str {
        match self {
            Self::FileNotFound { .. } => "The file will be created when you save settings.",
            Self::PermissionDenied { .. } => "Check file permissions and try again.",
            Self::ReadError { .. } => "Check that the file exists and is readable.",
            Self::InvalidJson { .. } => {
                "The file contains invalid JSON. Fix it manually or delete it to start fresh."
            }
            Self::WriteError { .. } => "Check disk space and file permissions.",
            Self::BackupFailed { .. } => "Check disk space. The original file was not modified.",
            Self::CircularSymlink { .. } => "Remove the circular symlink and try again.",
        }
    }
}

#[derive(Debug, Error)]
pub enum ConfigBundleError {
    #[error("Invalid bundle format: {0}")]
    InvalidFormat(String),

    #[error("Unsupported bundle version: {version}")]
    UnsupportedVersion { version: String },

    #[error("Export failed: {0}")]
    ExportFailed(String),

    #[error("Import failed: {0}")]
    ImportFailed(String),

    #[error("No components selected for export")]
    NoComponentsSelected,

    #[error("Project not found: {path}")]
    ProjectNotFound { path: PathBuf },
}

#[derive(Debug, Error)]
pub enum MCPHealthCheckError {
    #[error("Failed to spawn process: {0}")]
    ProcessSpawnFailed(String),

    #[error("Process exited early with code {code}")]
    ProcessExitedEarly { code: i32 },

    #[error("Invalid handshake response: {0}")]
    InvalidHandshakeResponse(String),

    #[error("HTTP request failed with status {status}")]
    HttpRequestFailed { status: u16 },

    #[error("Network error: {0}")]
    NetworkError(String),

    #[error("Health check timed out after {seconds}s")]
    Timeout { seconds: u64 },

    #[error("Server has no command or URL configured")]
    NoCommandOrUrl,
}

impl MCPHealthCheckError {
    pub fn recovery_suggestion(&self) -> &str {
        match self {
            Self::ProcessSpawnFailed(_) => "Check that the command exists and is in your PATH.",
            Self::ProcessExitedEarly { .. } => "The server crashed on startup. Check its logs.",
            Self::InvalidHandshakeResponse(_) => {
                "The server did not respond with valid MCP protocol."
            }
            Self::HttpRequestFailed { .. } => "Check the server URL and that it's running.",
            Self::NetworkError(_) => "Check your network connection and the server URL.",
            Self::Timeout { .. } => "The server took too long to respond. It may be overloaded.",
            Self::NoCommandOrUrl => {
                "Configure either a command (stdio) or URL (HTTP) for this server."
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_file_error_display() {
        let err = ConfigFileError::FileNotFound {
            path: PathBuf::from("/test/path.json"),
        };
        assert!(format!("{err}").contains("/test/path.json"));

        let err = ConfigFileError::InvalidJson {
            path: PathBuf::from("/test.json"),
            message: "unexpected EOF".to_string(),
        };
        assert!(format!("{err}").contains("/test.json"));
        assert!(format!("{err}").contains("unexpected EOF"));
    }

    #[test]
    fn test_fig_error_from_config() {
        let config_err = ConfigFileError::FileNotFound {
            path: PathBuf::from("/test"),
        };
        let fig_err: FigError = config_err.into();
        assert!(matches!(fig_err, FigError::Config(_)));
    }

    #[test]
    fn test_fig_error_from_io() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "not found");
        let fig_err: FigError = io_err.into();
        assert!(matches!(fig_err, FigError::Io(_)));
    }

    #[test]
    fn test_fig_error_from_bundle() {
        let bundle_err = ConfigBundleError::NoComponentsSelected;
        let fig_err: FigError = bundle_err.into();
        assert!(matches!(fig_err, FigError::Bundle(_)));
    }

    #[test]
    fn test_recovery_suggestions_non_empty() {
        let errors = vec![
            ConfigFileError::FileNotFound {
                path: PathBuf::new(),
            },
            ConfigFileError::PermissionDenied {
                path: PathBuf::new(),
            },
            ConfigFileError::ReadError {
                path: PathBuf::new(),
                message: String::new(),
            },
            ConfigFileError::InvalidJson {
                path: PathBuf::new(),
                message: String::new(),
            },
            ConfigFileError::WriteError {
                path: PathBuf::new(),
                message: String::new(),
            },
            ConfigFileError::BackupFailed {
                path: PathBuf::new(),
                message: String::new(),
            },
            ConfigFileError::CircularSymlink {
                path: PathBuf::new(),
            },
        ];
        for err in &errors {
            assert!(
                !err.recovery_suggestion().is_empty(),
                "Empty recovery suggestion for {err}"
            );
        }
    }

    #[test]
    fn test_mcp_health_check_recovery_suggestions_non_empty() {
        let errors: Vec<MCPHealthCheckError> = vec![
            MCPHealthCheckError::ProcessSpawnFailed("test".into()),
            MCPHealthCheckError::ProcessExitedEarly { code: 1 },
            MCPHealthCheckError::InvalidHandshakeResponse("test".into()),
            MCPHealthCheckError::HttpRequestFailed { status: 500 },
            MCPHealthCheckError::NetworkError("test".into()),
            MCPHealthCheckError::Timeout { seconds: 30 },
            MCPHealthCheckError::NoCommandOrUrl,
        ];
        for err in &errors {
            assert!(
                !err.recovery_suggestion().is_empty(),
                "Empty recovery suggestion for {err}"
            );
        }
    }
}
